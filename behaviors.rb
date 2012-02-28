module Core
  module Behaviors
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    autoload :AggregatedBehavior
    autoload :TrackedBehavior
    autoload :BelongsToAssociationPatch
    autoload :HasOneAssociationPatch
    autoload :Delegations

    included do
      ActiveRecord::Associations::BelongsToAssociation.send(:include, BelongsToAssociationPatch)
      ActiveRecord::Associations::HasOneAssociation.send(:include, HasOneAssociationPatch)
    end

    def new_recordify
      @_id_before_new_recodify = id
      self.id = nil
      @new_record = true
    end

    def persistentify(existing = nil)
      if existing
        self.id         = existing.id
        self.created_at = existing.created_at if respond_to?(:created_at)
        self.updated_at = existing.updated_at if respond_to?(:updated_at)
        @changed_attributes = {}
      else
        self.id = @_id_before_new_recordify
      end
      @new_record = false
      true
    end

    def updated_as_aggregated?
      !!@updated_as_aggregated
    end

    def tracked?
      false
    end

    module ClassMethods
      def aggregated
        include AggregatedBehavior
      end

      def tracked
        include TrackedBehavior
      end

      def represented_by(name)
        inverse_name = self.name.underscore.to_sym
        reflection = has_one name, :inverse_of => inverse_name, :conditions => {:is_current => true}
        reflection_klass = reflection.klass
        inversed_reflection = reflection_klass.reflect_on_association(inverse_name)
        inversed_reflection.options[:parts].each{ |part| delegate part, :"build_#{part}", :to => name }
        Array(inversed_reflection.options[:provides]).each do |p|
          case p
          when Symbol then delegate p, :to => name
          when Regexp then reflection_klass.instance_methods.grep(p).each{ |m| delegate m, :to => name }
          end
        end
        include reflection_klass.representation_delegations
        accepts_nested_attributes_for name
        default_scope includes(name)
      end

      def represents(name, options = {})
        reflection = belongs_to name, :inverse_of => self.name.underscore.to_sym
        parts = options[:with] or raise ArgumentError.new(":with option should be provided")
        reflection.options[:parts] = parts
        reflection.options[:provides] = options[:provides]
        parts.each do |name|
          belongs_to name
          accepts_nested_attributes_for name
        end
        default_scope includes(parts)
        @representation_delegations = Delegations.representation_module_for(self, *parts)
        include @representation_delegations
        tracked
      end

      def representation_delegations
        @representation_delegations
      end
    end
  end
end
