module Core
  module Behaviors
    module TrackedBehavior
      def save(*)
        run_callbacks(:save) do
          if content_changed? && persisted?
            stmt = current_to_false_arel_statement
            new_recordify
            klass = self.class
            begin
              klass.transaction do
                klass.connection.update stmt if super
              end
            rescue Exception => e
              pesistentify
              raise e
            end
          else
            super
          end
        end
      end

      def content_changed?
        changed? && changes.keys != ['is_current']
      end

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
    end
  end
end
