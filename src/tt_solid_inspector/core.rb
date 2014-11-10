#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  require File.join(PATH, "inspector_tool.rb")


  ### MENU & TOOLBARS ### ------------------------------------------------------

  unless file_loaded?(__FILE__)
    menu = UI.menu("Tools")
    menu.add_item(PLUGIN_NAME)  { self.inspect_solid }

    file_loaded(__FILE__)
  end


  ### MAIN SCRIPT ### ----------------------------------------------------------

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

end # module
