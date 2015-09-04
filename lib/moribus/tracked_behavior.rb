module Moribus
  # Adds tracked behavior to a model. A tracked model should have an
  # 'is_current' boolean column. Whenever the changed tracked object is about
  # to be saved, it memorizes its id, marks itself as a new record, and then
  # allows ActiveRecord to save it via standard means. If the record was
  # successfully saved, the memorized id is used to update the 'is_current'
  # flag for the effectively replaced record.
  module TrackedBehavior
    extend ActiveSupport::Concern

    included{ around_save :tracked_save_callback }

    # :nodoc:
    module ClassMethods
      # Return the column (attribute). Its value is used as a storage for
      # previous record id.
      attr_reader :preceding_key_column
    end

    # The main callback for tracked behavior (see module description). Note
    # that since AR objects are saved in transaction via AR::Transactions
    # module, no self.class.transaction{} block is used here. If an exception
    # has been raised during execution, the record returns to its persisted
    # state with its old id.
    def tracked_save_callback
      if content_changed? && persisted?
        to_new_record!
        set_parent
        begin
          # SQL UPDATE statement is executed in first place to prevent
          # crashing on uniqueness constraints with 'is_current' condition.
          if update_current
            set_lock
            yield
          end
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

    # Executes SQL UPDATE statement that sets value of 'is_current' attribute to false for a
    # record that is subject to update. If the record has locking column, will support
    # optimistic locking behavior.
    def update_current
      statement = current_to_false_sql_statement
      affected_rows = self.class.connection.update statement

      unless affected_rows == 1
        raise ActiveRecord::StaleObjectError.new(self, "update_current")
      end
      true
    end
    private :update_current

    # Set incremental lock_version column
    def set_lock
      lock_column_name = self.class.locking_column
      lock_value       = respond_to?(lock_column_name) && send(lock_column_name).to_i

      send("#{lock_column_name}=", lock_value + 1) if respond_to?("#{lock_column_name}=")
    end
    private :set_lock

    # Generate an arel statement to update the 'is_current' state of the
    # record to false. And perform the very same actions AR does for record
    # update, but using only a single 'is_current' column.
    #
    # Note: the more efficient #current_to_false_sql_statement method is
    # used instead. This is left in comments "for some future performance
    # miracle from the arel devs" (c Bruce) --a.kuzko 2012-03-07
    # def current_to_false_arel_statement
    #   klass = self.class
    #   self.is_current = false
    #   current_attribute = arel_attributes_values(false, false, ['is_current'])
    #   stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id)).arel.compile_update(current_attribute)
    #   self.is_current = true
    #   stmt
    # end
    # private :current_to_false_arel_statement

    # Generate SQL statement to be used to update 'is_current' state of record to false.
    # TODO: need to find way to track stale objects
    def current_to_false_sql_statement
      klass          = self.class
      is_current_col = klass.columns.detect { |c| c.name == "is_current" }
      id_column      = klass.columns.detect { |c| c.name == klass.primary_key }

      "UPDATE #{klass.quoted_table_name} SET \"is_current\" = #{klass.quote_value(false, is_current_col)} ".tap do |sql|
        sql << "WHERE #{klass.quoted_primary_key} = #{klass.quote_value(@_before_to_new_record_values[:id], id_column)} "
      end
    end
    private :current_to_false_sql_statement
  end
end
