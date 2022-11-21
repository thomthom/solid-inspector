module TT::Plugins::SolidInspector2

  # Shim for testing in older SU versions as a tool.
  class MockOverlay

    attr_reader :id, :name
    attr_writer :enabled

    def initialize(id, name)
      @id = id
      @name = name
      @enabled = false
    end

    def enabled?
      @enabled
    end

    def activate
      @enabled = true
      view = Sketchup.active_model.active_view
      start
      view.invalidate
    end

    # @param [Sketchup::View] view
    def deactivate(view)
      @enabled = false
      stop
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

    def start
    end

    def stop
    end

  end

end
