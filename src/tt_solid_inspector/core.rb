#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector

  require File.join(PATH, "error_finder.rb")
  require File.join(PATH, "instance.rb")


  ### MENU & TOOLBARS ### ------------------------------------------------------

  unless file_loaded?(__FILE__)
    m = UI.menu('Tools')
    m.add_item('Solid Inspector')  { self.inspect_solid }

    file_loaded(__FILE__)
  end


  ### MAIN SCRIPT ### ----------------------------------------------------------

  def self.inspect_solid
    Sketchup.active_model.select_tool(InspectorTool.new)
  end


  class InspectorTool

    def initialize
      @instance = nil
      @errors = []
      @current_error = 0
      @groups = []

      @status = "Click on solids to inspect. Use arrow keys to cycle between "\
        "errors. Press Return to zoom to error. Press Tab/Shift+Tab to cycle "\
        "though errors and zoom."

      if Sketchup.active_model.selection.empty?
        analyze(nil)
      else
        Sketchup.active_model.selection.each { |e|
          next unless Instance.is?(e)
          analyze(e)
          break
        }
      end
    end

    def analyze_old(instance)
      @instance = instance

      if @instance
        Sketchup.active_model.selection.clear
        Sketchup.active_model.selection.add(@instance)
        entities = Instance.definition(@instance).entities
        @transformation = @instance.transformation
      else
        entities = Sketchup.active_model.active_entities
        @transformation = Geom::Transformation.new()
      end

      # Any edge without two faces means an error in the surface of the solid.
      @current_error = 0
      @errors = entities.select { |e|
        e.is_a?(Sketchup::Edge) && e.faces.length != 2
      }

      # Group connected error-edges.
      @groups = []
      stack = @errors.clone
      until stack.empty?
        cluster = []
        cluster << stack.shift

        # Find connected errors
        edge = cluster.first
        haystack = ([edge.start.edges + edge.end.edges] - [edge]).first & stack
        until haystack.empty?
          e = haystack.shift

          if stack.include?(e)
            cluster << e
            stack.delete(e)
            haystack += ([e.start.edges + e.end.edges] - [e]).first & stack
          end
        end

        @groups << cluster
      end
    end

    def activate
      Sketchup.active_model.active_view.invalidate
      Sketchup.status_text = @status
    end

    def deactivate(view)
      view.invalidate
    end

    def resume(view)
      view.invalidate
      Sketchup.status_text = @status
    end

    def onLButtonUp(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      if Instance.is?(ph.best_picked)
        analyze(ph.best_picked)
      end
      view.invalidate
    end

    def onKeyUp(key, repeat, flags, view)
      return if @groups.empty?

      shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK

      # Iterate over the error found using Tab, Up/Down, Left/Right.
      # Tab will zoom to the current error.

      if key == 9 # Tab
        if shift
          @current_error = (@current_error - 1) % @groups.length
        else
          @current_error = (@current_error + 1) % @groups.length
        end
      end

      if key == VK_UP || key == VK_RIGHT
        @current_error = (@current_error + 1) % @groups.length
      end

      if key == VK_DOWN || key == VK_LEFT
        @current_error = (@current_error - 1) % @groups.length
      end

      if key == 13 || key == 9
        zoom_to_error(view)
      end

      #p key
      view.invalidate
    end

    def zoom_to_error(view)
      e = @groups[ @current_error ]
      view.zoom(e)
      # Adjust camera for the instance transformation
      camera = view.camera
      t = @transformation
      eye = camera.eye.transform(t)
      target = camera.target.transform(t)
      up = camera.up.transform(t)
      view.camera.set(eye, target, up)
    end

    def draw(view)
      @errors.each { |error|
        begin
          error.draw(view)
        rescue NotImplementedError
        end
      }
    end

    private

    def analyze(instance)
      puts "analyse"
      model = Sketchup.active_model # TODO
      entities = model.active_entities # TODO
      @errors = ErrorFinder.find_errors(entities)
      puts "> Errors: #{@errors.size}"
      nil
    end

  end # class InspectorTool


  ### DEBUG ### ------------------------------------------------------------

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::SolidInspector.reload
  #
  # @return [Integer] Number of files reloaded.
  def self.reload()
    original_verbose = $VERBOSE
    $VERBOSE = nil
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?(PATH) && File.exist?(PATH)
      x = Dir.glob(File.join(PATH, '*.{rb,rbs}')).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end

end # module
