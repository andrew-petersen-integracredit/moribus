module Core
  module Behaviors
    module Delegations
      def self.delegation_module_for(association_name)
        mod = Module.new
        mod.module_eval <<-RUBY
          def self.included(base)
            base.define_attribute_methods unless base.attribute_methods_generated?
          end

          def respond_to?(method, include_private = false)
            super || send(:#{association_name}).respond_to?(method)
          end

          def method_missing(method, *args, &block)
            if send(:#{association_name}).respond_to?(method)
              self.class.delegate method, :to => :#{association_name}
              send(method, *args, &block)
            else
              super
            end
          end
        RUBY
        mod
      end

      module Composition
        extend ActiveSupport::Concern

        included{ define_attribute_methods unless attribute_methods_generated? }

        def respond_to?(method, include_private = false)
          super || self.class.composed_associations.any?{ |name| send(name).respond_to?(method) }
        end

        def method_missing(method, *args, &block)
          self.class.composed_associations.each do |name|
            if send(name).respond_to?(method)
              self.class.delegate method, :to => name
              return send(method, *args, &block)
            end
          end
          super
        end
      end
    end
  end
end
