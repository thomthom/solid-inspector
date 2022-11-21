#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  class HeisenbugDialog < UI::WebDialog

    def initialize
      options = {
        :dialog_title    => PLUGIN_NAME,
        :scrollable      => false,
        :resizable       => false,
        :width           => 400,
        :height          => 400,
        :left            => 400,
        :top             => 300
      }

      super(options)

      # Because this might run on older SketchUp with Ruby 1.8 and no StdLib we
      # must avoid using the JSON lib and do special handling of the callbacks.
      add_action_callback("callback") { |dialog, params|
        case params
        when "html_ready"
          # Ignore.
        when "close_window"
          dialog.close
        else
          warn "Unknown callback: #{callback}"
        end
      }
      add_action_callback("open_forum_thread") { |dialog, params|
        UI.openURL("http://forums.sketchup.com/t/solid-inspector-heisenbug/30988")
        dialog.close
      }

      self.min_width = options[:width]
      self.min_height = options[:height]

      set_size(options[:width], options[:height])

      html_file = File.join(PATH, "html", "heisenbug.html")
      set_file(html_file)
    end

  end # class

end # module TT::Plugins::SolidInspector2
