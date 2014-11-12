#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  class Window < UI::WebDialog

    def initialize(options)
      super(options)

      # For windows that should not be resizable we make sure to set the size
      # after creating the dialog. Otherwise it might be remembering old values
      # and use that instead.
      unless options[:resizable]
        set_size(options[:width], options[:height])
      end

      @events = {}

      add_action_callback("callback") { |dialog, name|
        puts "Callback: 'callback(#{name})'"
        json = get_element_value("SU_BRIDGE")
        if json && json.size > 0
          data = JSON.parse(json)
        else
          data = []
        end
        trigger_events(dialog, name, data)
      }

      on("html_ready") { |dialog|
        puts "Window.html_ready"
        @on_ready.call(dialog) unless @on_ready.nil?
      }

      on("close_window") { |dialog|
        puts "Window.close_window"
        dialog.close
      }
    end

    # Simplifies calling the JavaScript in the webdialog by taking care of
    # generating the JS command needed to execute it.
    #
    # @param [String] function
    # @param [Mixed] *arguments
    #
    # @return [Nil]
    def call(function, *arguments)
      # Calling inspect will ensure strings are quoted and convert most basic
      # Ruby data types to JS types. This is a very naive version and will need
      # tweaking if more types are needed.
      js_args = arguments.map { |x| x.to_json }.join(", ")
      javascript = "#{function}(#{js_args});"
      execute_script(javascript)
    end

    def on(event, &block)
      return false if block.nil?
      @events[event] ||= []
      @events[event] << block
      true
    end

    # Platform neutral method that ensures that window stays on top of the main
    # window on both platforms. Also captures any blocks given and executes it
    # when the HTML DOM is ready.
    def show(&block)
      if visible?
        bring_to_front
      else
        @on_ready = block
        if Sketchup.platform == :platform_osx
          show_modal() {} # Empty block to prevent the block from propagating.
        else
          super() {}
        end
      end
    end

    private :show_modal

    private

    def trigger_events(dialog, event, data = [])
      if @events[event]
        @events[event].each { |callback|
          callback.call(dialog, data)
        }
        true
      else
        false
      end
    end

    def class_name
      self.class.name.split("::").last
    end

  end # class

end # module TT::Plugins::SolidInspector2
