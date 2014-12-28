#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector

  class UpgradeDialog < UI::WebDialog

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
      add_action_callback("callback") {|dialog, params|
        case params
        when "ignore"
          Sketchup.write_default(PLUGIN_ID, "IgnoreUpgrade", true)
          dialog.close
        when "later"
          dialog.close
        when "install"
          dialog.close
        when "installManually"
          UI.openURL("http://extensions.sketchup.com/content/solid-inspector²")
          dialog.close
        else
          warn "Unknown callback: #{params}"
        end
      }

      self.min_width = options[:width]
      self.min_height = options[:height]

      set_size(options[:width], options[:height])

      html_file = File.join(PATH, "html", "upgrade.html")
      set_file(html_file)
    end

  end # class


  def self.upgrade_installed?
    $LOAD_PATH.any? { |path|
      begin
        root_rb = File.join(path, "tt_solid_inspector2.rb")
        File.exist?(root_rb)
      rescue => error
        warn error.inspect
        warn error.backtrace.join("\n")
        false
      end
    }
  end


  def self.ignore_upgrade?
    Sketchup.read_default(PLUGIN_ID, "IgnoreUpgrade", false)
  end


  if Sketchup.version.to_i >= 14 && !self.ignore_upgrade?
    unless self.upgrade_installed?
      @window = UpgradeDialog.new
      @window.show
    end
  end

end # module TT::Plugins::SolidInspector
