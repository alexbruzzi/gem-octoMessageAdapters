require 'set'

require 'octocore'
require 'octocore/callbacks'

module Octo
  # Adapter to perform all adapter operations
  module BaseAdapter
    # Default set of Octo Events Callback
    DEFAULT_CALLBACKS = [:after_app_init, :after_app_login, :after_app_logout, 
      :after_page_view, :after_productpage_view]

    module ClassMethods
      # Add Callbacks for adapter
      # @param [Array] *callback Array of allowed callbacks
      def callback_for(*callback)
        @callbacks += callbacks
      end

      # Enterprise check to allow all enterprises
      # @return [Bool] check Allow all Enterprises
      def enterprise_only(check = true)
        @enterprise_only = check
      end

      # Returns callbacks
      # @return [Array] Callbacks array
      def callbacks
        @callbacks ||= DEFAULT_CALLBACKS
      end

      # Return settings for adapter
      # @return [Hash] Adapter settings
      def settings
        adapter_id = self.const_get(:ADAPTER_ID)
        @adapter_settings = []
        Octo::Enterprise.all.each do |enterprise|
          opt = {
            enterprise_id: enterprise.id, 
            adapter_id: adapter_id, 
            enable: true
          }
          @adapter_settings << Octo::AdapterDetails.get_cached(opt)
        end
      end

      # Adapter Activation method
      # @param [Key] arg Reference to method
      def activate_if(arg)
        @activate_key = arg
      end

      # Adapter Transform method
      # @param [Key] arg Reference to method
      def transform(arg)
        @transformation_key = arg
      end

      # Adapter dispatcher method
      # @param [Key] Refrence to method
      def dispatcher(arg)
        @dispatcher_key = arg
      end

      # Performs message transformation
      # It converts message into specific format
      # @param [Hash] msg Message
      # @return Transformed message
      def perform_transformation(msg)
        self.send(@transformation_key, msg)
      end

      # Performs activation of adapter
      # @return [Bool] adapter activated or not
      def activate
        self.send(@activate_key)
      end

      # To perform http request to adapter
      # @param [Hash] t_msg Transformed Messsage
      def dispatch(t_msg)
        self.send(@dispatcher_key, t_msg)
      end

      # Call transform and sends transformed method to dispatcher
      # @param [Hash] msg Message
      def perform(msg)
        t_msg = perform_transformation msg
        dispatch t_msg
      end
    end
    
    # Default Included method of Module
    # @param [Module] receiver Module reference
    def self.included(receiver)
      receiver.extend ClassMethods
    end
  end

  # Adapter class which sets all adapters
  class Adapter
    class << self
      # Valid Adapters List
      @@valid_adapters = []

      # Set all Adapters
      def set_adapters
        @adapters = get_adapters
        @adapters.each do |adapter|
          adapter.send(:settings)
          if adapter.send(:activate)
            @@valid_adapters << adapter
          end
        end
      end

      # Set all Callbacks
      def set_callbacks
        @@valid_adapters.each do |adapter|
          adapter.send(:callbacks).each do |callback|
            Octo::Callbacks.send(callback, lambda { |opts|
              adapter.send(:perform, opts)
            })
          end
        end
      end

      # Fetch adapters list
      def get_adapters
        ObjectSpace.each_object(Module).select { |m| 
          m.included_modules.include? Octo::BaseAdapter
        }
      end

      # After connect method called after Octo connection
      def after_connect
        set_adapters
        set_callbacks
      end
    end
  end
end

require 'messageadapter/hello_adapter'