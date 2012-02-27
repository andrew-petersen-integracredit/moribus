module Core
  module Behaviors
    module BelongsToAssociationPatch
      extend ActiveSupport::Concern

      included do
        def updated?
          @updated || load_target.updated_as_aggregated?
        end
      end
    end
  end
end
