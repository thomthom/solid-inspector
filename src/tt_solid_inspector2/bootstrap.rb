#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------



module TT::Plugins::SolidInspector2
  if Sketchup.version.to_i < 14
    require File.join(PATH, "compatibility.rb")
  else

    require File.join(PATH, "settings.rb")
    require File.join(PATH, "error_reporter", "error_reporter.rb")

    server = if Settings.local_error_server?
      "http://sketchup.thomthom.local/extensions/report_error"
    else
      "http://sketchup.thomthom.net/extensions/report_error"
    end

    config = {
      :extension_id => PLUGIN_ID,
      :extension    => @extension,
      :server       => server,
      :support_url  => "http://www.thomthom.net/software/example/support",
      :debug        => Settings.debug_mode?
    }
    ERROR_REPORTER = ErrorReporter.new(config)

    begin
      require File.join(PATH, "core.rb")
    rescue Exception => error
      ERROR_REPORTER.handle(error)
    end

  end # if Sketchup.version

end # module
