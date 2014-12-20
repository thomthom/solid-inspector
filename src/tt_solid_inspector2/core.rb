#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------



module TT::Plugins::SolidInspector2
  if Sketchup.version.to_i < 14
    if @extension.respond_to?(:uncheck)
      # Must defer the disabling with a timer otherwise the setting won't be
      # saved. I assume SketchUp save this setting after it loads the extension.
      UI.start_timer(0, false) { @extension.uncheck }
    end

    options = {
      :dialog_title    => PLUGIN_NAME,
      :scrollable      => false,
      :resizable       => true,
      :width           => 400,
      :height          => 200,
      :left            => 400,
      :top             => 300
    }
    html_file = File.join(PATH, "html", "compatibility.html")
    @window = UI::WebDialog.new(options)
    @window.set_size(400, 200)
    @window.set_file(html_file)
    @window.show
  else

  require File.join(PATH, "inspector_tool.rb")


  PATH_IMAGES = File.join(PATH, "images").freeze


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
      x = Dir.glob(File.join(PATH, "*.{rb,rbs}")).each { |file|
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
