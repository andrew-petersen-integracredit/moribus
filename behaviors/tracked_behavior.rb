module Core
  module Behaviors
    # Adds tracked behavior to a model. A tracked model should have an
    # 'is_current' boolean column. Whenever the changed tracked object is about
    # to be saved, it memorizes its id, marks itself as a new record, and then
    # allows ActiveRecord to save it via standard means. If the record was
    # successfully saved, the memorized id is used to update the 'is_current'
    # flag for the effectively replaced record.
    module TrackedBehavior
      extend ActiveSupport::Concern

      included{ around_save :tracked_save_callback }

      # The main callback for tracked behavior (see module description). Note
      # that since AR objects are saved in transaction via AR::Transactions
      # module, no self.class.transaction{} block is used here. If an exception
      # has been raised during execution, the record returns to its persisted
      # state with its old id.
      def tracked_save_callback
        if content_changed? && persisted?
          stmt = current_to_false_sql_statement
          to_new_record!
          begin
            self.class.connection.update stmt if yield
          ensure
            to_persistent! if new_record?
          end
        else
          yield
        end
      end
      private :tracked_save_callback

      # Return true if any of the columns except 'is_current' has been changed.
      def content_changed?
        changed? && changes.keys != ['is_current']
      end
      private :content_changed?

      # Generates arel statement to be used to update 'is_current' state of record to false. Performs
      # the very same actions AR does for record update, but uses only single 'is_current' column.
      #
      # Note: this is replaced by #current_to_false_sql_statement for performance reasons.
      # def current_to_false_arel_statement
      #   klass = self.class
      #   self.is_current = false
      #   current_attribute = arel_attributes_values(false, false, ['is_current'])
      #   stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id)).arel.compile_update(current_attribute)
      #   self.is_current = true
      #   stmt
      # end
      # private :current_to_false_arel_statement

      # Generates SQL statement to be used to update 'is_current' state of record to false.
      def current_to_false_sql_statement
        klass = self.class
        "UPDATE #{klass.quoted_table_name} SET \"is_current\" = #{klass.quote_value(false)} WHERE #{klass.quoted_primary_key} = #{klass.quote_value(id)}"
      end
      private :current_to_false_sql_statement
    end
  end
end
