module Core
  module Behaviors
    module HasOneAssociationPatch
      extend ActiveSupport::Concern

      included{ alias_method_chain :remove_target!, :tracked }

      def remove_target_with_tracked!(method)
        if target.tracked?
          target.update_attribute(:is_current, false)
        else
          remove_target_without_tracked!(method)
        end
      end
    end
  end
end
