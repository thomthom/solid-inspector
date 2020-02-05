#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2
  module Execution

    def self.delay(seconds, &block)
      done = false
      UI.start_timer(seconds, false) do
        next if done
        done = true
        block.call
      end
    end

    def self.defer(&block)
      self.delay(0.0, &block)
    end


    class Debounce

      # @param [Float] delay in seconds
      def initialize(delay)
        @delay = delay
        @time_out_timer = nil
      end

      def call(&block)
        if @time_out_timer
          UI.stop_timer(@time_out_timer)
          @time_out_timer = nil
        end
        @time_out_timer = UI.start_timer(@delay, &block)
        nil
      end

    end # class

  end
end # module
