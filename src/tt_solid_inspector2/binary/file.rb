#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  require File.join(PATH, "binary", "types.rb")


  module Binary

    class File < ::File

      include Types

      def initialize(*args)
        super
        self.binmode
      end

      def read(*args)
        if !args.empty? && is_binary_arguments?(args)
          read_binary(*args)
        else
          super
        end
      end

      def sniff(*args)
        position = pos()
        data = read(*args)
        seek(position, IO::SEEK_SET)
        data
      end

      private

      def is_binary_arguments?(args)
        args[0].is_a?(String) || args[0].is_a?(Binary::Struct)
      end

      def read_binary(*args)
        if args.size == 1 && args[0].is_a?(Binary::Struct)
          struct = args[0]
          return struct.read(self)
        end
        struct = Binary::Struct.new(*args)
        read_binary(struct)
      end

      def compute_struct_size(struct)
        sizes = struct.map { |type| DATA_SIZES[type] }
        sizes.inject(:+)
      end

    end # class

  end # module
end # module TT::Plugins::SolidInspector2
