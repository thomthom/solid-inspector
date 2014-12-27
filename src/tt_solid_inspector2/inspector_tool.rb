#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2

  require File.join(PATH, "error_finder.rb")
  require File.join(PATH, "geometry.rb")
  require File.join(PATH, "inspector_window.rb")
  require File.join(PATH, "instance.rb")
  require File.join(PATH, "key_codes.rb")
  require File.join(PATH, "legend.rb")


  class InspectorTool

    include KeyCodes


    def initialize
      @errors = []
      @current_error = 0
      @filtered_errors = nil

      @legends = []
      @screen_legends = nil

      @entities = nil
      @instance_path = nil
      @transformation = nil

      @window = nil
      @deactivating = false
      nil
    end


    def activate
      @deactivating = false

      @window ||= create_window
      @window.show

      Sketchup.active_model.active_view.invalidate
      update_ui
      nil
    end


    def deactivate(view)
      if @window && @window.visible?
        @deactivating = true
        @window.close
      end
      view.invalidate
      nil
    end


    def resume(view)
      @screen_legends = nil
      view.invalidate
      update_ui
      nil
    end


    def onMouseMove(flags, x, y, view)
      if @screen_legends
        point = Geom::Point3d.new(x, y, 0)
        legend = @screen_legends.find { |legend| legend.mouse_over?(point, view) }
        view.tooltip = legend ? legend.tooltip : ""
      end
      nil
    end


    def onLButtonUp(flags, x, y, view)
      # Allow errors to be selected by clicking the legends.
      if @screen_legends
        point = Geom::Point3d.new(x, y, 0)
        legend = @screen_legends.find { |legend| legend.mouse_over?(point, view) }
        if legend
          if legend.is_a?(LegendGroup)
            error = legend.legends.first.error
          else
            legend.error
          end
          index = filtered_errors.find_index(error)
          if index
            @current_error = index
            view.invalidate
            return nil
          end
        end
      end

      # Pick a new instance to inspect.
      ph = view.pick_helper
      ph.do_pick(x, y)
      view.model.selection.clear
      if Instance.is?(ph.best_picked)
        view.model.selection.add(ph.best_picked)
      end
      analyze
      view.invalidate
      nil
    end


    def onKeyUp(key, repeat, flags, view)
      return if @errors.empty?

      shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK

      # Iterate over the error found using Tab, Up/Down, Left/Right.
      # Tab will zoom to the current error.
      errors = filtered_errors

      if key == KEY_TAB
        if @current_error.nil?
          @current_error = 0
        else
          if shift
            @current_error = (@current_error - 1) % errors.size
          else
            @current_error = (@current_error + 1) % errors.size
          end
        end
      end

      if key == VK_UP || key == VK_RIGHT
        if @current_error.nil?
          @current_error = 0
        else
          @current_error = (@current_error + 1) % errors.size
        end
      end

      if key == VK_DOWN || key == VK_LEFT
        if @current_error.nil?
          @current_error = 0
        else
          @current_error = (@current_error - 1) % errors.size
        end
      end

      if key == KEY_RETURN || key == KEY_TAB
        unless @current_error.nil?
          zoom_to_error(view)
        end
      end

      if key == KEY_ESCAPE
        deselect_tool
        #return true
      end

      view.invalidate
      false # Returning true would cancel the key event.
    end


    if Sketchup.version.to_i < 15
      def getMenu(menu)
        context_menu(menu)
      end
    else
      def getMenu(menu, flags, x, y, view)
        context_menu(menu, flags, x, y, view)
      end
    end


    def draw(view)
      filtered_errors.each { |error|
        error.draw(view, @transformation)
      }

      draw_circle_around_current_error(view)

      if @screen_legends.nil?
        start_time = Time.now
        @screen_legends = merge_close_legends(@legends, view)
        @legend_time = Time.now - start_time
      end
      if Settings.debug_mode? && Settings.debug_legend_merge? && @legend_time
        view.draw_text([20, 20, 0], "Legend Merge: #{@legend_time}")
      end
      @screen_legends.each { |legend|
        legend.draw(view)
      }
      nil
    end


    private


    def analyze
      #puts "analyse"

      model = Sketchup.active_model
      entities = model.active_entities
      instance_path = model.active_path || []
      transformation = Geom::Transformation.new

      unless model.selection.empty?
        #puts "> Selection:"
        instance = Sketchup.active_model.selection.find { |entity|
          Instance.is?(entity)
        }
        #puts "  > Instance: #{instance.inspect}"
        if instance
          definition = Instance.definition(instance)
          entities = definition.entities
          instance_path << instance
          transformation = instance.transformation
        end
      end

      #puts "> Entities: #{entities}"
      #puts "> Instance Path: #{instance_path.inspect}"
      #puts "> Transformation: #{transformation.to_a}"

      @filtered_errors = nil
      @current_error = nil
      @errors = ErrorFinder.find_errors(entities, transformation)
      @entities = entities
      @instance_path = instance_path
      @transformation = transformation

      update_webdialog
      update_legends
      update_ui
      nil
    end


    def deselect_tool
      Sketchup.active_model.select_tool(nil)
    end


    def context_menu(menu, flags = nil, x = nil, y = nil, view = nil)
      view ||= Sketchup.active_model.active_view

      item = menu.add_item("Detect Short Edges") {
        Settings.detect_short_edges = !Settings.detect_short_edges?
        reanalyze_short_edges
        view.invalidate
      }
      menu.set_validation_proc(item)  {
        Settings.detect_short_edges? ? MF_CHECKED : MF_UNCHECKED
      }

      # TODO: Move this into a slider in the WebDialog instead.
      threshold = Settings.short_edge_threshold
      item = menu.add_item("Short Edge Threshold: #{threshold}") {
        prompts = ["Edge Length"]
        defaults = [threshold]
        result = UI.inputbox(prompts, defaults, "Short Edge Threshold")
        if result
          Settings.short_edge_threshold = result[0]
          reanalyze_short_edges
          view.invalidate
        end
      }
      menu.set_validation_proc(item)  {
        Settings.detect_short_edges? ? MF_ENABLED : MF_GRAYED
      }

      if Settings.debug_mode?
        menu.add_separator

        item = menu.add_item("Debug Legend Merge Performance") {
          Settings.debug_legend_merge = !Settings.debug_legend_merge?
          view.invalidate
        }
        menu.set_validation_proc(item)  {
          Settings.debug_legend_merge? ? MF_CHECKED : MF_UNCHECKED
        }
      end
    end


    def create_window
      window = InspectorWindow.new
      window.set_on_close {
        unless @deactivating
          Sketchup.active_model.select_tool(nil)
        end
      }
      window.on("html_ready") { |dialog|
        analyze
        Sketchup.active_model.active_view.invalidate
      }
      window.on("fix_all") { |dialog|
        fix_all
        Sketchup.active_model.active_view.invalidate
      }
      window.on("fix_group") { |dialog, data|
        fix_group(data["type"])
        Sketchup.active_model.active_view.invalidate
      }
      window.on("select_group") { |dialog, data|
        select_group(data[0])
        Sketchup.active_model.active_view.invalidate
      }
      window.on("keydown") { |dialog, data|
        forward_key(:onKeyDown, data)
      }
      window.on("keyup") { |dialog, data|
        forward_key(:onKeyUp, data)
      }
      window
    end


    def draw_circle_around_current_error(view)
      return false if @current_error.nil?
      return false if filtered_errors.empty?

      error = filtered_errors[@current_error]

      vertices = Set.new
      error.entities.each { |entity|
        if entity.respond_to?(:vertices)
          vertices.merge(entity.vertices)
        end
      }

      screen_points = vertices.to_a.map { |vertex|
        world_point = vertex.position.transform(@transformation)
        screen_point = view.screen_coords(world_point)
        screen_point.z = 0 # TODO: Share code with DrawingHelper.
        screen_point
      }

      bounds = Geom::BoundingBox.new
      bounds.add(screen_points)

      corner1 = bounds.corner(BB_LEFT_FRONT_BOTTOM)
      corner2 = bounds.corner(BB_RIGHT_BACK_TOP)
      diameter = corner1.distance(corner2)
      diameter = [diameter, 20].max
      radius = diameter / 2
      segments = 64
      circle = Geometry.circle2d(bounds.center, X_AXIS, radius, segments)

      view.line_stipple = ''
      view.line_width = 2
      view.drawing_color = SolidErrors::SolidError::ERROR_COLOR_EDGE
      view.draw2d(GL_LINE_LOOP, circle)
      true
    end


    def forward_key(method, jquery_event)
      key = jquery_event["key"]
      repeat = false
      flags = 0
      view = Sketchup.active_model.active_view
      #p [method, key]
      send(method, key, repeat, flags, view)
      nil
    end


    def filtered_errors
      if @filtered_errors.nil?
        errors = @errors
      else
        errors = @errors.grep(@filtered_errors)
      end
      errors
    end


    def fix_all
      all_errors_fixed = ErrorFinder.fix_errors(@errors, @entities)
      process_fix_all_results(all_errors_fixed)
      analyze
    end


    def fix_group(type)
      error_klass = SolidErrors.const_get(type)
      errors = @errors.select { |error|
        error.is_a?(error_klass)
      }
      all_errors_fixed = ErrorFinder.fix_errors(errors, @entities)
      process_fix_results(all_errors_fixed, error_klass)
      analyze
    end


    def process_fix_results(all_errors_fixed, error_klass)
      unless all_errors_fixed
        UI.messagebox(error_klass.description)
      end
      nil
    end


    def process_fix_all_results(all_errors_fixed)
      unless all_errors_fixed
        message = "Some errors could not be automatically fixed. "\
          "Manually inspect and correct the errors, then run the tool again."
        UI.messagebox(message)
      end
      nil
    end


    def select_group(type)
      if type.nil?
        @filtered_errors = nil
      else
        klass = SolidErrors.const_get(type)
        @filtered_errors = klass
      end
      @current_error = nil
      nil
    end


    def group_errors(errors)
      groups = {}
      errors.each { |error|
        unless groups.key?(error.class)
          groups[error.class] = {
            :type        => error.class.type_name,
            :name        => error.class.display_name,
            :description => error.class.description,
            :fixable     => error.fixable?,
            :errors      => []
          }
        end
        groups[error.class][:errors] << error
      }
      groups
    end


    def reanalyze_short_edges
      @errors.reject! { |error| error.is_a?(SolidErrors::ShortEdge) }
      if Settings.detect_short_edges?
        ErrorFinder.find_short_edges(@entities) { |edge|
          @errors << SolidErrors::ShortEdge.new(edge)
        }
      end
      update_legends
      update_webdialog
      nil
    end


    def update_legends
      @legends = @errors.grep(SolidErrors::ShortEdge).map { |error|
        ShortEdgeLegend.new(error, @transformation)
      }
      @screen_legends = nil
    end


    def update_webdialog
      grouped_errors = group_errors(@errors)
      @window.call("list_errors", grouped_errors)
    end


    def update_ui
      message = "Click on solids to inspect. Use arrow keys to cycle between "\
        "errors. Press Return to zoom to error. Press Tab/Shift+Tab to cycle "\
        "though errors and zoom."
      Sketchup.status_text = message
      nil
    end


    def zoom_to_error(view)
      error = filtered_errors[@current_error]
      view.zoom(error.entities)
      # Adjust camera for the instance transformation
      camera = view.camera

      point = view.camera.target
      offset = view.pixels_to_model(1000, point)
      #p offset
      offset_point = point.offset(view.camera.direction.reverse, offset)
      vector = point.vector_to(offset_point)
      if vector.valid?
        tr_offset = Geom::Transformation.new(vector)
        tr = @transformation * tr_offset
      else
        tr = @transformation
      end

      eye = camera.eye.transform(tr)
      target = camera.target.transform(tr)
      up = camera.up.transform(tr)
      view.camera.set(eye, target, up)

      @screen_legends = nil
      nil
    end


    def merge_close_legends(legends, view)
      merged = []
      legends.each { |legend|
        next unless legend.on_screen?(view)
        group = merged.find { |l| legend.intersect?(l, view) }
        if group
          group.add_legend(legend)
        else
          merged << LegendGroup.new(legend)
        end
      }
      merged
    end


  end # class InspectorTool
end # module TT::Plugins::SolidInspector2
