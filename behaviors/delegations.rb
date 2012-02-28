module Core
  module Behaviors
    module Delegations
      EXCLUDE_METHODS_REGEXP = /^_|\?$|^reset|_cast$|_was$|_change!?$/

      def self.representation_module_for(owner, *association_names)
        owner.define_attribute_methods unless owner.attribute_methods_generated?
        owner_instance_methods = owner.instance_methods
        mod = Module.new
        association_names.each do |name|
          mod.module_eval("def effective_#{name}; #{name} || build_#{name}; end")
          klass = owner.reflect_on_association(name).klass
          klass.define_attribute_methods unless klass.attribute_methods_generated?
          klass.generated_attribute_methods.instance_methods.select{ |m| m !~ EXCLUDE_METHODS_REGEXP }.each do |method|
            mod.delegate method, :to => :"effective_#{name}" unless method.in? owner_instance_methods
          end
        end
        mod
      end
    end
  end
end
