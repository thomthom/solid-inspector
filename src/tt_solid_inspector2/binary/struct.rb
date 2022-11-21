#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  require File.join(PATH, "binary", "file.rb")
  require File.join(PATH, "binary", "types.rb")


  module Binary

    class Struct

      include Binary::Types

      # Byte sizes for String.unpack

      BIT_8  = 1
      BIT_16 = 2
      BIT_32 = 4
      BIT_64 = 8

      DATA_SIZES = {
          CHAR       => BIT_8,
          INT_16_T   => BIT_16,
          INT_32_T   => BIT_32,
          INT_64_T   => BIT_64,

          UCHAR      => BIT_8,
          UINT_16_T  => BIT_16,
          UINT_32_T  => BIT_32,
          UINT_64_T  => BIT_64,

          UINT_16_BE => BIT_16,
          UINT_32_BE => BIT_32,

          UINT_16_LE => BIT_16,
          UINT_32_LE => BIT_32,
      }

      def initialize(*args)
        unless args.all? { |arg| arg.is_a?(String) }
          raise ArgumentError, "Invalid struct format"
        end
        @structure = args
        @data_format = @structure.join
      end

      def read(arg)
        if arg.is_a?(Binary::File)
          struct = arg
          return read( struct.read(size()) )
        end
        packed_data = arg
        data = packed_data.unpack(@data_format)
        (data.size == 1) ? data[0] : data
      end

      def size
        sizes = @structure.map { |type| DATA_SIZES[type] }
        sizes.inject(:+)
      end

    end # class

  end # module
end # module TT::Plugins::SolidInspector2
