#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2

  require File.join(PATH, "error_finder.rb")
  require File.join(PATH, "inspector_window.rb")
  require File.join(PATH, "instance.rb")
  require File.join(PATH, "key_codes.rb")


  class InspectorTool

    include KeyCodes


    def initialize
      @errors = []
      @current_error = 0

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
      view.invalidate
      update_ui
      nil
    end


    def onLButtonUp(flags, x, y, view)
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

      if key == KEY_TAB
        if shift
          @current_error = (@current_error - 1) % @errors.size
        else
          @current_error = (@current_error + 1) % @errors.size
        end
      end

      if key == VK_UP || key == VK_RIGHT
        @current_error = (@current_error + 1) % @errors.size
      end

      if key == VK_DOWN || key == VK_LEFT
        @current_error = (@current_error - 1) % @errors.size
      end

      if key == KEY_RETURN || key == KEY_TAB
        zoom_to_error(view)
      end

      view.invalidate
      false # Returning true would cancel the key event.
    end


    def draw(view)
      @errors.each { |error|
        error.draw(view, @transformation)
      }
      nil
    end


    private


    def analyze
      puts "analyse"

      model = Sketchup.active_model
      entities = model.active_entities
      instance_path = model.active_path || []
      transformation = Geom::Transformation.new

      unless model.selection.empty?
        puts "> Selection:"
        instance = Sketchup.active_model.selection.find { |entity|
          Instance.is?(entity)
        }
        puts "  > Instance: #{instance.inspect}"
        if instance
          definition = Instance.definition(instance)
          entities = definition.entities
          instance_path << instance
          transformation = instance.transformation
        end
      end

      puts "> Entities: #{entities}"
      puts "> Instance Path: #{instance_path.inspect}"
      puts "> Transformation: #{transformation.to_a}"

      @current_error = 0
      @errors = ErrorFinder.find_errors(entities, transformation)
      @entities = entities
      @instance_path = instance_path
      @transformation = transformation

      # Push results to webdialog.
      grouped_errors = group_errors(@errors)
      #puts JSON.pretty_generate(grouped_errors)
      @window.call("list_errors", grouped_errors)
      nil
    end


    def bulk_fix(errors)
      # For performance reasons we sort out the different errors and handle them
      # differently depending on their traits.
      entities_to_be_erased = Set.new
      remaining_errors = []
      errors.each { |error|
        if error.is_a?(EraseToFix)
          # We want to collect all the entities that can be erased and erase
          # them in one bulk operation for performance gain.
          entities_to_be_erased << error.entity
        else
          # All the others will be fixed one by one after erasing entities.
          remaining_errors << error
        end
      }

      # We want to erase the edges that are separating faces that are being
      # erased. Otherwise the operation leaves stray edges behind.
      stray_edges = Set.new
      entities_to_be_erased.grep(Sketchup::Face) { |face|
        face.edges.each { |edge|
          if edge.faces.all? { |f| entities_to_be_erased.include?(f) }
            stray_edges << edge
          end
        }
      }
      entities_to_be_erased.merge(stray_edges)

      # For extra safety we validate the entities.
      entities_to_be_erased.reject! { |entity| entity.deleted? }

      # Now we're ready to perform the cleanup operations.
      model = @entities.model
      begin
        model.start_operation("Fix Solid", true)
        @entities.erase_entities(entities_to_be_erased.to_a)
        remaining_errors.each { |error|
          begin
            error.fix
          rescue NotImplementedError => e
            p e
          end
        }
        model.commit_operation
      rescue
        #model.abort_operation
        model.commit_operation
        raise
      end
      nil
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
      window
    end


    def fix_all
      bulk_fix(@errors)
      analyze
    end


    def fix_group(type)
      error_klass = PLUGIN.const_get(type)
      errors = @errors.select { |error|
        error.is_a?(error_klass)
      }
      bulk_fix(errors)
      analyze
    end


    def group_errors(errors)
      groups = {}
      errors.each { |error|
        unless groups.key?(error.class)
          groups[error.class] = {
            :type        => error.class.type_name,
            :name        => error.class.display_name,
            :description => error.class.description,
            :errors      => []
          }
        end
        groups[error.class][:errors] << error
      }
      groups
    end


    def update_ui
      message = "Click on solids to inspect. Use arrow keys to cycle between "\
        "errors. Press Return to zoom to error. Press Tab/Shift+Tab to cycle "\
        "though errors and zoom."
      Sketchup.status_text = message
      nil
    end


    def zoom_to_error(view)
      error = @errors[@current_error]
      view.zoom(error.entity)
      # Adjust camera for the instance transformation
      camera = view.camera
      tr = @transformation
      eye = camera.eye.transform(tr)
      target = camera.target.transform(tr)
      up = camera.up.transform(tr)
      view.camera.set(eye, target, up)
      nil
    end

  end # class InspectorTool
end # module TT::Plugins::SolidInspector2
