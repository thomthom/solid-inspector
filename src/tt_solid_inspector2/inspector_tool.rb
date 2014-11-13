#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


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
      @window = nil
      @deactivating = false
      nil
    end


    def activate
      @deactivating = false
      #analyze

      @window = InspectorWindow.new
      @window.set_on_close {
        unless @deactivating
          Sketchup.active_model.select_tool(nil)
        end
      }
      @window.on("html_ready") { |dialog|
        #grouped_errors = group_errors(@errors)
        #puts JSON.pretty_generate(grouped_errors)
        #dialog.call("list_errors", grouped_errors)
        analyze
      }
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

      puts "> Errors: #{@errors.size}"
      #puts @errors.join("\n")
      error_types = {}
      @errors.each { |error|
        error_types[error.class] ||= 0
        error_types[error.class] += 1
      }
      error_types.each { |klass, num_errors|
        puts "  > #{klass.name}: #{num_errors}"
      }

      # Push results to webdialog.
      grouped_errors = group_errors(@errors)
      #puts JSON.pretty_generate(grouped_errors)
      @window.call("list_errors", grouped_errors)
      nil
    end


    def group_errors(errors)
      groups = {}
      errors.each { |error|
        unless groups.key?(error.class)
          groups[error.class] = {
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
