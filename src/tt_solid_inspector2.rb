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
  PLUGIN          = self
  PLUGIN_ID       = "TT_SolidInspector2".freeze
  PLUGIN_NAME     = "Solid Inspector²".freeze
  PLUGIN_VERSION  = "2.4.2".freeze

  # Resource paths
  file = __FILE__.dup
  file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
  FILENAMESPACE = File.basename(file, ".*")
  PATH_ROOT     = File.dirname(file).freeze
  PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze


  ### EXTENSION ### ------------------------------------------------------------

  unless file_loaded?(__FILE__)
    loader = File.join(PATH, "bootstrap.rb")
    @extension = SketchupExtension.new(PLUGIN_NAME, loader)
    @extension.description = "Inspect and fix problems with geometry that "\
      "should be manifold (solids)."
    @extension.version     = PLUGIN_VERSION
    @extension.copyright   = "Thomas Thomassen © 2010-2015"
    @extension.creator     = "Thomas Thomassen (thomas@thomthom.net)"
    Sketchup.register_extension(@extension, true)
  end

  end # module SolidInspector2
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
