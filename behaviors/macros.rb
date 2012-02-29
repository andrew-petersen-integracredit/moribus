module Core
  module Behaviors
    module Macros
      def share(*args)
        options = args.extract_options!
        association_name = options[:with]
        attributes = args.dup

        before_save do
          unless (associated = send(association_name)).nil?
            attributes.each{ |attr| associated.send(:"#{attr}=", send(attr)) }
          end
        end
      end

      def provides(*args)
        options = args.extract_options!
        reflection = reflect_on_association(options[:for])
        klass = reflection.klass
        name_as_inversed = reflection.options[:inverse_of]
        args.each do |association_name|
          klass.delegate(association_name, :to => name_as_inversed)
          association_reflection = reflect_on_association(association_name)
          if association_reflection.respond_to?(:delegated_attribute_methods)
            klass.send(:include, association_reflection.delegated_attribute_methods)
          end
        end
      end

      def has_one_current(name, options = {})
        reflection = has_one name, options.merge(:conditions => {:is_current => true})
        reflection.options[:is_current] = true
        accepts_nested_attributes_for name
        reflection
      end

      def has_aggregated(name, options = {})
        reflection = belongs_to(name, options)
        reflection.options[:aggregated] = true
        accepts_nested_attributes_for name
        extend_has_aggregated_reflection(reflection)
        reflection
      end
    end
  end
end
