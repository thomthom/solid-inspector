#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "sketchup.rb"
require "extensions.rb"

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module SolidInspector2

  ### CONSTANTS ### ------------------------------------------------------------

  # Plugin information
  PLUGIN_ID       = "TT_SolidInspector2".freeze
  PLUGIN_NAME     = "Solid Inspector²".freeze
  PLUGIN_VERSION  = "2.0.0".freeze

  # Resource paths
  FILENAMESPACE = File.basename(__FILE__, ".*")
  PATH_ROOT     = File.dirname(__FILE__).freeze
  PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze


  ### EXTENSION ### ------------------------------------------------------------

  unless file_loaded?(__FILE__)
    loader = File.join(PATH, "core.rb")
    ex = SketchupExtension.new(PLUGIN_NAME, loader)
    ex.description = "Inspect and fix problems with geometry that should be "\
      "manifold (solids)."
    ex.version     = PLUGIN_VERSION
    ex.copyright   = "Thomas Thomassen © 2010-2014"
    ex.creator     = "Thomas Thomassen (thomas@thomthom.net)"
    Sketchup.register_extension(ex, true)
  end

  end # module SolidInspector2
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
