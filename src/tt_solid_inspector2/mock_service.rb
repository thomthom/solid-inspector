module TT::Plugins::SolidInspector2

  # Shim for testing in older SU versions as a tool.
  class MockService

    attr_writer :enabled

    def initialize
      @enabled = false
    end

    def enabled?
      @enabled
    end

    def activate
      @enabled = true
      view = Sketchup.active_model.active_view
      start(view)
      view.invalidate
    end

    # @param [Sketchup::View] view
    def deactivate(view)
      @enabled = false
      stop(view)
      view.invalidate
    end

    # @param [Sketchup::View] view
    def suspend(view)
      view.invalidate
    end

    # @param [Sketchup::View] view
    def resume(view)
      view.invalidate
    end

    def start(view)
    end

    def stop(view)
    end

  end

end
