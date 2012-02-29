module Core
  module Behaviors
    module Extensions
      module HasCurrentExtension
        def remove_target!(*)
          target.update_attribute(:is_current, false)
        end
      end
    end
  end
end
