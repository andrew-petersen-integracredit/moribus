module Core
  module Behaviors
    # Adds attributed behavior to a model.
    module AttributedBehavior
      extend ActiveSupport::Concern
      
      included{ around_save :attributed_save_callback }
      
      def attributed_save_callback
        self.customer_data_updater = 
          CustomerDataUpdater.first
        yield
      end
      private :attributed_save_callback
    
    end
  end
end