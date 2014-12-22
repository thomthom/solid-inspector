#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2
  module Binary

    module Types

      # Standard Types

      CHAR       = "c".freeze
      INT_16_T   = "s" .freeze
      INT_32_T   = "l" .freeze
      INT_64_T   = "q" .freeze

      UCHAR      = "C".freeze
      UINT_16_T  = "S" .freeze
      UINT_32_T  = "L" .freeze
      UINT_64_T  = "Q" .freeze

      UINT_16_BE = "n".freeze
      UINT_32_BE = "N".freeze

      UINT_16_LE = "v".freeze
      UINT_32_LE = "V".freeze

      # Windows Types

      DWORD = UINT_32_LE
      LONG  = UINT_32_LE
      WORD  = UINT_16_LE

    end # module

  end # module
end # module TT::Plugins::SolidInspector2
