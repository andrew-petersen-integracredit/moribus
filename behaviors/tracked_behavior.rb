module Core
  module Behaviors
    module TrackedBehavior
      extend ActiveSupport::Concern

      included{ around_save :tracked_save_callback }

      def tracked_save_callback
        if content_changed? && persisted?
          stmt = current_to_false_arel_statement
          new_recordify
          begin
            self.class.connection.update stmt if yield
          ensure
            persistentify if new_record?
          end
        else
          yield
        end
      end
      private :tracked_save_callback

      def content_changed?
        changed? && changes.keys != ['is_current']
      end
      private :tracked_save_callback

      def tracked?
        true
      end

      def current_to_false_arel_statement
        klass = self.class
        self.is_current = false
        current_attribute = arel_attributes_values(false, false, ['is_current'])
        stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id)).arel.compile_update(current_attribute)
        self.is_current = true
        stmt
      end
      private :current_to_false_arel_statement
    end
  end
end
