#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------



module TT::Plugins::SolidInspector2
  if Sketchup.version.to_i < 14
    require File.join(PATH, "compatibility.rb")
    @window = CompatibilityWarning.new(@extension)
    @window.show
  else

  require File.join(PATH, "debug_tools.rb")
  require File.join(PATH, "error_window.rb")
  require File.join(PATH, "inspector_tool.rb")
  require File.join(PATH, "settings.rb")


  PATH_IMAGES  = File.join(PATH, "images").freeze
  PATH_GL_TEXT = File.join(PATH_IMAGES, "text").freeze
  PATH_HTML    = File.join(PATH, "html").freeze


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

      debug_menu.add_item("Error Dialog") {
        begin
          2 / 0
        rescue => error
          @error_window = ErrorWindow.new(error)
          @error_window.show
        end
      }
    end

    toolbar = UI.toolbar(PLUGIN_NAME)
    toolbar.add_item(cmd_inspector)
    toolbar.restore

    file_loaded(__FILE__)
  end


  ### MAIN SCRIPT ### ----------------------------------------------------------

  # Constants for Sketchup::Face.mesh
  PolygonMeshPoints   = 0
  PolygonMeshUVQFront = 1
  PolygonMeshUVQBack  = 2
  PolygonMeshNormals  = 4

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


  def self.inspect_solid
    Sketchup.active_model.select_tool(InspectorTool.new)
  end


  ### DEBUG ### ------------------------------------------------------------

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::SolidInspector2.reload
  #
  # @return [Integer] Number of files reloaded.
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

  end # if Sketchup.version

end # module
