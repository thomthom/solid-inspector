#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  # TT::Plugins::SolidInspector2.debug_mode = true
  @debug_mode = Sketchup.read_default(PLUGIN_ID, "DebugMode", false)

  def self.debug_mode?
    @debug_mode
  end
  def self.debug_mode=(boolean)
    @debug_mode = boolean ? true : false
    Sketchup.write_default(PLUGIN_ID, "DebugMode", @debug_mode)
  end

end # module TT::Plugins::SolidInspector2
