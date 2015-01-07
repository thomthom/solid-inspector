#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


require "speedup.rb"
require 'testup/testcase'


module TT::Plugins::SolidInspector2
 module Profiling

  class PR_Mesh < SpeedUp::ProfileTest

    include TestUp::SketchUpTestUtilities


    def setup
      discard_model_changes

      project_path = File.expand_path(File.join(__dir__, ".."))
      tests_path = File.join(project_path, "Tests", "Solid Inspector 2")
      filename = File.join(tests_path, "TC_ErrorFinder", "SolidTest.skp")
      Sketchup.open_file(filename)

      model = Sketchup.active_model
      @entities = model.definitions["Group#3"].entities
    end


    def profile_find_self_intersections
      errors = []
      ErrorFinder.find_self_intersections(@entities) { |edge, face, point|
        errors << [edge, face, point]
      }
    end

  end # class

 end # module
end # module
