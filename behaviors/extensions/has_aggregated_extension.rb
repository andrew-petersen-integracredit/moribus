module Core
  module Behaviors
    module Extensions
      module HasAggregatedExtension
        def updated?
          @updated || load_target.updated_as_aggregated?
        end

        def reader
          super || build
        end

        class Helper
          EXCLUDE_METHODS_REGEXP = /^_|\?$|^reset|_cast$|_was$|_change!?$/

          attr_reader :model, :reflection

          def initialize(model, reflection)
            @model, @reflection = model, reflection
          end

          def extend
            define_delegation_module(reflection)
            add_delegated_methods(reflection)
            include_delegation_module(reflection)
          end

          def define_delegation_module(reflection)
            def reflection.delegated_attribute_methods
              @delegated_attribute_methods ||= Module.new
            end
          end
          private :define_delegation_module

          def add_delegated_methods(reflection)
            mod = reflection.delegated_attribute_methods
            model.define_attribute_methods unless model.attribute_methods_generated?
            model_instance_methods = model.instance_methods
            methods_to_delegate = methods_to_delegate_to(reflection) - model_instance_methods
            methods_to_delegate.each do |method|
              mod.delegate method, :to => name
            end
          end
          private :add_delegated_methods

          def methods_to_delegate_to(reflection)
            klass = reflection.klass
            enum_methods = klass.reflect_on_all_enumerated.map do |reflection|
              name = reflection.name
              [name, "#{name}="]
            end
            klass.define_attribute_methods unless klass.attribute_methods_generated?
            attribute_methods = klass.generated_attribute_methods.instance_methods.select{ |m| m !~ EXCLUDE_METHODS_REGEXP }
            attribute_methods + enum_methods.flatten
          end
          private :methods_to_delegate_to

          def include_delegation_module(reflection)
            model.send(:include, reflection.delegated_attribute_methods)
          end
          private :include_delegation_module

          def name
            @reflection_name ||= reflection.name
          end
          private :name
        end
      end
    end
  end
end
