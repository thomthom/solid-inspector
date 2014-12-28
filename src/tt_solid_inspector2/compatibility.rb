#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  class CompatibilityWarning < UI::WebDialog

    def initialize(extension)
      options = {
        :dialog_title    => PLUGIN_NAME,
        :scrollable      => false,
        :resizable       => false,
        :width           => 400,
        :height          => 250,
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
      add_action_callback("open_extension_warehouse") { |dialog, params|
        UI.openURL("http://extensions.sketchup.com/content/solid-inspector")
        dialog.close
      }

      self.min_width = options[:width]
      self.min_height = options[:height]

      set_size(options[:width], options[:height])

      html_file = File.join(PATH, "html", "compatibility.html")
      set_file(html_file)

      disable_extension(extension)
    end

    private

    def disable_extension(extension)
      if extension.respond_to?(:uncheck)
        # Must defer the disabling with a timer otherwise the setting won't be
        # saved. I assume SketchUp save this setting after it loads the extension.
        UI.start_timer(0, false) { extension.uncheck }
      end
      nil
    end

  end # class


  @window = CompatibilityWarning.new(@extension)
  @window.show

end # module TT::Plugins::SolidInspector2
