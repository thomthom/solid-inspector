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


    # TT::Plugins::SolidInspector2::Settings.debug_mode = true
    @debug_mode = self.read("DebugMode", false)
    def self.debug_mode?
      @debug_mode
    end
    def self.debug_mode=(boolean)
      @debug_mode = boolean ? true : false
      self.write("DebugMode", @debug_mode)
    end


    # TT::Plugins::SolidInspector2::Settings.local_error_server = true
    @local_error_server = self.read("LocalErrorServer", false)
    def self.local_error_server?
      @local_error_server
    end
    def self.local_error_server=(boolean)
      @local_error_server = boolean ? true : false
      self.write("LocalErrorServer", @local_error_server)
    end


    @debug_legend_merge = self.read("DebugLegendMerge", false)
    def self.debug_legend_merge?
      @debug_legend_merge
    end
    def self.debug_legend_merge=(boolean)
      @debug_legend_merge = boolean ? true : false
      self.write("DebugLegendMerge", @debug_legend_merge)
    end


    @debug_error_report = self.read("DebugErrorReport", false)
    def self.debug_error_report?
      @debug_error_report
    end
    def self.debug_error_report=(boolean)
      @debug_error_report = boolean ? true : false
      self.write("DebugErrorReport", @debug_error_report)
    end


    @debug_color_internal_faces = self.read("DebugColorInternalFaces", false)
    def self.debug_color_internal_faces?
      @debug_color_internal_faces
    end
    def self.debug_color_internal_faces=(boolean)
      @debug_color_internal_faces = boolean ? true : false
      self.write("DebugColorInternalFaces", @debug_color_internal_faces)
    end


    @detect_short_edges = self.read("DetectShortEdges", false)
    def self.detect_short_edges?
      @detect_short_edges
    end
    def self.detect_short_edges=(boolean)
      @detect_short_edges = boolean ? true : false
      self.write("DetectShortEdges", @detect_short_edges)
    end


    @short_edge_threshold = self.read("ShortEdgeThreshold", 3.mm).to_l
    def self.short_edge_threshold
      @short_edge_threshold
    end
    def self.short_edge_threshold=(length)
      @short_edge_threshold = length.to_l
      self.write("ShortEdgeThreshold", @short_edge_threshold.to_f)
    end


    @search_nested_instances = self.read("SearchNestedInstances", false)
    def self.search_nested_instances?
      @search_nested_instances
    end
    def self.search_nested_instances=(boolean)
      @search_nested_instances = boolean ? true : false
      self.write("SearchNestedInstances", @search_nested_instances)
    end

  end # module Settings
end # module TT::Plugins::SolidInspector2
