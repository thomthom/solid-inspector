#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------


module TT::Plugins::SolidInspector2
  module Instance

    # Returns the definition for a +Group+, +ComponentInstance+ or +Image+
    #
    # @param [:definition, Sketchup::Group, Sketchup::Image] instance
    #
    # @return [Sketchup::ComponentDefinition, Mixed]
    def self.definition(instance)
      if instance.respond_to?(:definition)
        begin
          return instance.definition
        rescue
          # Previously this was the first check, but too many extensions modify
          # Sketchup::Group.definition with a method which is bugged so to avoid
          # all the complaints about extensions not working due to this the call
          # is trapped is a rescue block and any errors will make it fall back
          # to using the old way of finding the group definition.
        end
      end
      if instance.is_a?(Sketchup::Group)
        # (i) group.entities.parent should return the definition of a group.
        # But because of a SketchUp bug we must verify that
        # group.entities.parent returns the correct definition. If the returned
        # definition doesn't include our group instance then we must search
        # through all the definitions to locate it.
        if instance.entities.parent.instances.include?(instance)
          return instance.entities.parent
        else
          Sketchup.active_model.definitions.each { |definition|
            return definition if definition.instances.include?(instance)
          }
        end
      elsif instance.is_a?(Sketchup::Image)
        Sketchup.active_model.definitions.each { |definition|
          if definition.image? && definition.instances.include?(instance)
            return definition
          end
        }
      end
      return nil # Given entity was not an instance of an definition.
    end


    # Query to whether it's a Group or ComponentInstance
    #
    # @param [Sketchup::Entity] entity
    #
    # @return [Boolean]
    def self.is?(entity)
      entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
    end

  end # module Instance
end # module TT::Plugins::SolidInspector2
