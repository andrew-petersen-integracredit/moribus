module Moribus
  module Extensions
    # Minor extension for Rails' +has_one+ association that will help
    # dealing with current record assignment.
    module HasCurrentExtension
      # Sets 'is_current' flag of overridden record to false, instead
      # of deleting it or setting foreign key to nil.
      def remove_target!(*)
        if target.new_record?
          target.is_current = false
        else
          # Use custom update to not run ActiveRecord optimistic locking
          # and not update lock_version column
          klass              = target.class
          is_current_col     = klass.columns.detect { |c| c.name == "is_current" }
          id_column          = klass.columns.detect { |c| c.name == klass.primary_key }

          sql =  "UPDATE #{klass.quoted_table_name} SET \"is_current\" = #{klass.quote_value(false, is_current_col)} "
          sql << "WHERE #{klass.quoted_primary_key} = #{klass.quote_value(target.send(klass.primary_key), id_column)} "

          klass.connection.update sql
        end
      end
    end
  end
end
