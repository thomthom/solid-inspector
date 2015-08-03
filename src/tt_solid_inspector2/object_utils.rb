#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2
  module ObjectUtils

    private

    def object_info(extra_info = "")
      %{#<#{self.class.name}:#{object_id_hex}#{extra_info}>}
    end

    def object_id_hex
      "0x%x" % (self.object_id << 1)
    end

  end # class ObjectUtils
end # module TT::Plugins::SolidInspector2
