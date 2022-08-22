module Moribus
  module Extensions
    # Minor extension for Rails' +has_one+ association that will help
    # dealing with current record assignment.
    module HasCurrentExtension
      # Sets 'is_current' flag of overridden record to false, instead
      # of deleting it or setting foreign key to nil.
      def remove_target!(*)
        # Use custom update to avoid running ActiveRecord optimistic locking
        # and to avoid updating lock_version column:
        if target.new_record?
          target.is_current = false
          target.updated_at = Time.zone.now if has_updated_at_column?
        else
          klass = target.class

          sql =  "UPDATE #{klass.quoted_table_name} " \
                 "SET \"is_current\" = #{klass.connection.quote(false)} "

          sql << %{, "updated_at" = #{klass.connection.quote(Time.zone.now)} } if has_updated_at_column?

          sql << "WHERE #{klass.quoted_primary_key} = " \
                 "#{klass.connection.quote(target.send(klass.primary_key))} "

          klass.connection.update sql
        end
      end

      private def has_updated_at_column?
        target.class.column_names.include?("updated_at")
      end
    end
  end
end
