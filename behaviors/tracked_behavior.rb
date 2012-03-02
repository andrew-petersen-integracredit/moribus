module Core
  module Behaviors
    # Adds tracked behavior to a model. A tracked model should have 'is_current' boolean column.
    # Whenever the changed tracked object is about to be saved, it memorizes it's id, marks itself
    # as a new record, and then allows ActiveRecord to save it via standard means. If the record
    # was successfully saved, memorized id is used to update 'is_current' flag for effectively
    # replaced record
    module TrackedBehavior
      extend ActiveSupport::Concern

      included{ around_save :tracked_save_callback }

      # The main callback for tracked behavior (see module description). Note that since AR objects
      # are saved in transaction via AR::Transactions module, no self.class.transaction{} block is
      # used here. If exception has been raised during execution, the record returns to it persisted
      # state with old id.
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

      # Returns true if any of columns except 'is_current' has been changed
      def content_changed?
        changed? && changes.keys != ['is_current']
      end
      private :tracked_save_callback

      # Returns true, indicating tracked behavior of the record
      def tracked?
        true
      end

      # Generates arel statement to be used to update 'is_current' state of record to false. Performs
      # the very same actions AR does for record update, but uses only single 'is_current' column.
      #
      # Note: this can be greatly optimized if everyone OK with executing string like (simplified)
      # "UPDATE tracked_objects SET is_current = 'f' WHERE id = #{replaced_id}"
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
