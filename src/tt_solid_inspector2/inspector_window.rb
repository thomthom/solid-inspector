#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  require File.join(PATH, "window.rb")


  class InspectorWindow < Window

    def initialize
      options = {
        :dialog_title    => PLUGIN_NAME,
        :preferences_key => "#{PLUGIN_ID}_#{class_name}",
        :scrollable      => false,
        :resizable       => true,
        :width           => 400,
        :height          => 600,
        :left            => 200,
        :top             => 200
      }
      super(options)

      self.min_width = 400
      self.min_height = 250

      on("html_ready") { |dialog|
        #dialog.call("localize", LH.strings)
      }

      on("fix_all") { |dialog, data|
        #puts ""
        #puts "InspectorWindow.fix_all"
      }

      on("select_group") { |dialog, data|
        #puts ""
        #puts "InspectorWindow.select_group"
        #p data
      }

      html_file = File.join(PATH_HTML, "inspector.html")
      set_file(html_file)
    end

  end # class

end # module TT::Plugins::SolidInspector2
