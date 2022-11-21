#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  require File.join(PATH, "debug_tools.rb")
  require File.join(PATH, "inspector_tool.rb")
  require File.join(PATH, "settings.rb")

  PATH_IMAGES  = File.join(PATH, "images").freeze
  PATH_GL_TEXT = File.join(PATH_IMAGES, "text").freeze
  PATH_HTML    = File.join(PATH, "html").freeze

  ### MAIN SCRIPT ### ----------------------------------------------------------

  # Constants for Tool.onCancel
  REASON_ESC = 0
  REASON_REACTIVATE = 1
  REASON_UNDO = 2

  # Constants for Sketchup::View.draw_points
  DRAW_OPEN_SQUARE     = 1
  DRAW_FILLED_SQUARE   = 2
  DRAW_PLUS            = 3
  DRAW_CROSS           = 4
  DRAW_STAR            = 5
  DRAW_OPEN_TRIANGLE   = 6
  DRAW_FILLED_TRIANGLE = 7

  # Constants for Geom::BoundingBox.corner
  BB_LEFT_FRONT_BOTTOM  = 0
  BB_RIGHT_FRONT_BOTTOM = 1
  BB_LEFT_BACK_BOTTOM   = 2
  BB_RIGHT_BACK_BOTTOM  = 3
  BB_LEFT_FRONT_TOP     = 4
  BB_RIGHT_FRONT_TOP    = 5
  BB_LEFT_BACK_TOP      = 6
  BB_RIGHT_BACK_TOP     = 7


  # TT::Plugins::SolidInspector2.inspect_solid
  def self.inspect_solid
    Sketchup.active_model.select_tool(InspectorTool.new)
  rescue Exception => error
    ERROR_REPORTER.handle(error)
  end

  class AppObserver < Sketchup::AppObserver

    def expectsStartupModelNotifications
      true
    end

    def register_overlay(model)
      overlay = InspectorTool.new(overlay: true)
      overlay.description = "Inspects selected instances for manifold issues."
      begin
        model.overlays.add(overlay)
      rescue ArgumentError => error
        # If the overlay was already registerred.
        warn error
      end
    end
    alias_method :onNewModel, :register_overlay
    alias_method :onOpenModel, :register_overlay

  end

  # TT::Plugins::SolidInspector2.start_overlays
  def self.start_overlays
    observer = AppObserver.new
    Sketchup.add_observer(observer)

    # In the case of installing or enabling the extension we need to
    # register the overlay.
    model = Sketchup.active_model
    observer.register_overlay(model) if model
  rescue Exception => error
    ERROR_REPORTER.handle(error)
  end


  ### MENU & TOOLBARS ### ------------------------------------------------------

  unless file_loaded?(__FILE__)
    cmd = UI::Command.new(PLUGIN_NAME) {
      self.inspect_solid
    }
    cmd.tooltip = "Inspect and repair solid groups and component."
    cmd.status_bar_text = "Inspect and repair solid groups and components."
    cmd.small_icon = File.join(PATH_IMAGES, 'Inspector-16.png')
    cmd.large_icon = File.join(PATH_IMAGES, 'Inspector-24.png')
    cmd_inspector = cmd

    menu = UI.menu("Tools")
    menu.add_item(cmd_inspector)

    if Settings.debug_mode?
      debug_menu = menu.add_submenu("#{PLUGIN_NAME} Debug Tools")

      debug_menu.add_item("Debug Reversed Faces") {
        Sketchup.active_model.select_tool(DebugFaceReversedTool.new)
      }
    end

    toolbar = UI.toolbar(PLUGIN_NAME)
    toolbar.add_item(cmd_inspector)
    toolbar.restore

    if defined?(Sketchup::Overlay)
      self.start_overlays
    end

    file_loaded(__FILE__)
  end


  ### DEBUG ### ----------------------------------------------------------------

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::SolidInspector2.reload
  #
  # @return [Integer] Number of files reloaded.
  # noinspection RubyGlobalVariableNamingConvention
  def self.reload()
    original_verbose = $VERBOSE
    $VERBOSE = nil
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?(PATH) && File.exist?(PATH)
      x = Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each { |file|
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
