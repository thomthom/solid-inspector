#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  require File.join(PATH, "window.rb")


  class ErrorWindow < Window

    def self.handle(error)
      @error_window = ErrorWindow.new(error)
      @error_window.show
    end

    def initialize(error)
      height = (Sketchup.platform == :platform_osx) ? 420 : 490
      options = {
        :dialog_title    => PLUGIN_NAME,
        :preferences_key => "#{PLUGIN_ID}_#{class_name}5",
        :scrollable      => false,
        :resizable       => true,
        :width           => 400,
        :height          => height,
        :left            => 200,
        :top             => 200
      }
      super(options)

      self.min_width = options[:width]
      self.min_height = options[:height]

      report = generate_report(error)

      if Settings.debug_error_report?
        puts ""
        puts report
        puts ""
      end

      on("html_ready") { |dialog|
        #dialog.call("localize", LH.strings)
        call("error_report", report)
        UI.beep
      }

      on("report") { |dialog, data|
        puts "Report"
        base_url = "http://thomthom.net/software/sketchup"
        extension_url = "#{base_url}/solid_inspector2/report-error"
        UI.openURL(extension_url)
      }

      html_file = File.join(PATH_HTML, "error.html")
      set_file(html_file)
    end

    private

    def generate_report(error)
      report = <<EOT
#{PLUGIN_NAME} (#{PLUGIN_VERSION})

Extension Path: #{PATH_ROOT}

SketchUp Version: #{Sketchup.version} (#{bitness})

Ruby Version: #{RUBY_VERSION}
Ruby Platform: #{RUBY_PLATFORM}

----------

Error:

#{error.inspect}
#{error.backtrace.join("\n")}

----------

Loaded Features:

#{$LOADED_FEATURES.join("\n")}

EOT
      report
    end

    def bitness
      if Sketchup.respond_to?(:is_64bit?) && Sketchup.is_64bit?
        "64bit"
      else
        "32bit"
      end
    end

  end # class

end # module TT::Plugins::SolidInspector2
