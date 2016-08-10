require 'set'
require 'resque'
require 'resque-scheduler'
require 'octocore'

module Octo
  # Generic Adapter module
  module MessageAdapter
    module ClassMethods
      
      # Returns an array of adapters
      # @return [Array] Adapters array
      def adapters
        @adapters ||= []
      end

      # Returns the list of default callbacks
      # @returns [Set] List of default callbacks
      def callback_list
        Set.new(%w(:after_app_init, :after_app_login, :after_app_logout, 
          :after_page_view, :after_productpage_view))
      end

      # Sending message object to adapters
      # @param [Octo::Message::Message] msg Message Object
      def send_to_adapters(msg)
        adapters.each do |ad|
          ad.each do |a_detail| 
            if a_detail[:enterprise_id] == msg.eid
              Resque.enqueue(Octo::AdapterSender, ad, msg)
            end
          end
        end
      end
    end
    
    # On including this module
    def self.included(receiver)
      begin
        Octo.connect_with(File.join(Dir.pwd, 'Octo/config'))
        receiver.extend ClassMethods
        # Octo::AdapterMethods.load_callbacks
      rescue Exception => e
        Octo.logger.error(e)
      end
    end
  end

  # Generic Adapter Methods module
  module AdapterMethods
    module ClassMethods

      # Adding callbacks to allowed callbacks
      # @param [Key] callback
      def callbacks_for(callback)
        @allowed_callbacks << callback
      end

      # Return list of allowed callbacks
      # Its a seperate list for every adapter to manage caallbacks
      # Example: callbacks_for :after_app_init, :after_app_login
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
        begin
          adapter_id = klass.const_get(:ADAPTER_ID)
          Octo::Enterprise.all.each do |enterprise|
            opt = {
              enterprise_id: enterprise.id, 
              adapter_id: adapter_id, 
              enable: true
            }
            @adapters[klass] << Octo::AdapterDetails.get_cached(opt).first
          end
        rescue Exception => e
          Octo.logger.error(e)
        end
      end

      # Loading all allowed callbacks
      def self.load_callbacks
        begin
          allowed_callback.each do |event|
            Octo::Callbacks.send(event, lambda { |opts|
              msg_obj = Octo::Message::Message.new(opts)
              Octo::MessageAdapter.send_to_adapters msg_obj
            })
          end
        rescue Exception => e
          Octo.logger.error(e)
        end
      end

      # Fetch Adapter settings
      # @param [Module] klass of an Adapter
      # @param [Octo::Message::Message] msg Message Object
      def settings(kclass, msg)
        @adapters[kclass].select { |adapter| 
          adapter[:enterprise_id] == msg.eid
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
    # @param [Octo::Message::Message] msg Message Object
    def self.perform(adapter, msg)
      adapter.send(:sender, msg)
    end
  end
end

# require 'octomessageadapters/ga_adapter'

Octo.send(:include, Octo::MessageAdapter)