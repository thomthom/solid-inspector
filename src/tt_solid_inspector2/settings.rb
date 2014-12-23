#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2
  module Settings

    def self.read(key, default = nil)
      Sketchup.read_default(PLUGIN_ID, key, default)
    end

    def self.write(key, value)
      Sketchup.write_default(PLUGIN_ID, key, value)
    end


    @debug_mode = self.read("DebugMode", false)
    def self.debug_mode?
      @debug_mode
    end
    def self.debug_mode=(boolean)
      @debug_mode = boolean ? true : false
      self.write("DebugMode", @debug_mode)
    end


    @detect_short_edges = self.read("DetectShortEdges", false)
    def self.detect_short_edges?
      @detect_short_edges
    end
    def self.detect_short_edges=(boolean)
      @detect_short_edges = boolean ? true : false
      self.write("DetectShortEdges", @detect_short_edges)
    end


    @short_edge_threshold = self.read("ShortEdgeThreshold", 3.mm)
    def self.short_edge_threshold
      @short_edge_threshold
    end
    def self.short_edge_threshold=(length)
      @short_edge_threshold = length.to_l
      self.write("ShortEdgeThreshold", @short_edge_threshold)
    end

  end # module Settings
end # module TT::Plugins::SolidInspector2
