module Core
  module Behaviors
    module Extensions
      extend ActiveSupport::Concern
      extend ActiveSupport::Autoload

      autoload :HasAggregatedExtension
      autoload :HasCurrentExtension

      module ClassMethods
        def extend_has_aggregated_reflection(reflection)
          HasAggregatedExtension::Helper.new(self, reflection).extend
        end
      end

      def association(name)
        association = super
        reflection = self.class.reflect_on_association(name)
        case reflection.macro
        when :belongs_to
          association.extend(HasAggregatedExtension) if reflection.options[:aggregated]
        when :has_one
          association.extend(HasCurrentExtension) if reflection.options[:is_current]
        end
        association
      end
    end
  end
end
