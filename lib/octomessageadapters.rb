require 'set'
require 'resque'
require 'resque-scheduler'
require 'octocore'

require 'octomessageadapters/ga_adapter'

module Octo

  # Generic Adapter module
  module MessageAdapter

    module ClassMethods
      
      # Returns an array of adapters
      def adapters
        @adapters ||= {}
      end

      # Returns the list of default callbacks
      def callback_list
        [:after_app_init, :after_app_login, :after_app_logout, 
          :after_page_view, :after_productpage_view]
      end

      # Sending message object to adapters
      # @param [Octo::Message::Message] msg_obj Message Object
      def send_to_adapters(msg_obj)
        adapters.each do |ad|
          ad.each do |a_detail| 
            if a_detail[:enterprise_id] == msg_obj.eid
              Resque.enqueue(Octo::AdapterSender, ad, msg_obj)
            end
          end
        end
      end
    end
    
    # On including this module
    def self.included(receiver)
      receiver.extend ClassMethods
      AdapterSettings.load_callbacks
    end

  end

  # Generic Adapter Methods module
  module AdapterMethods
    module ClassMethods

      # Adding callbacks to allowed callbacks
      # @param [Key] callback
      def callbacks_for(callback)
        @allowed_callback << callback
      end

      # Return list of allowed callbacks
      def allowed_callback
        @allowed_callbacks ||= MessageAdapter.callback_list
      end

      # Activating adapter 
      def activate_if
        @adapters[self] = yield
      end

      # Registering adapter
      # @param [Module] klass of an Adapter
      def register(klass)
        adapter_id = klass.const_get(:ADAPTER_ID)
        Octo::Enterprise.all.each do |enterprise|
          opt = {
            enterprise_id: enterprise.id, 
            adapter_id: adapter_id, 
            enable: true
          }
          @adapters[klass] << Octo::AdapterDetails.get_cached(opt).first
        end
      end

      # Loading all allowed callbacks
      def load_callbacks
        allowed_callback.each do |event|
          Octo::Callbacks.send(event, lambda { |opts|
            msg_obj = Octo::Message::Message.new(opts)
            MessageAdapter.send_to_adapters msg_obj
          })
        end
      end

      # Fetch Adapter settings
      # @param [Module] klass of an Adapter
      # @param [Octo::Message::Message] msg_obj Message Object
      def settings(kclass, msg_obj)
        @adapters[kclass].select {|adapter| 
          adapter[:enterprise_id] == msg_obj.eid
        }.first.settings
      end
      
    end

    # On including this module
    def self.included(receiver)
      receiver.extend ClassMethods
    end

  end

  # Resque scheduler module to call adapters
  module AdapterSender
    @queue = :message_adapter

    # Resque perform method to allocate adapters
    # @param [Module] adapter
    # @param [Octo::Message::Message] msg_obj Message Object
    def self.perform(adapter, msg_obj)
      adapter.sender(msg_obj)
    end
  end
end