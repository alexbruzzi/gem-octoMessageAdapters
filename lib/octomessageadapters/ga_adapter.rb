require 'staccato'

module Octo

  # Module for Google Analytics
  module GaAdapter
    include Octo::AdapterSettings

    ADAPTER_ID = 0

    # Set callbacks for GA adapter
    # callbacks_for :after_app_init, :after_app_login

    # To register adapter for usage
    register self

    module ClassMethods

      # Create connection using GA Tracking ID
      # @param [Octo::Message::Message] msg_obj Message Object
      def connect(msg_obj)
        @tracker = Staccato.tracker(settings(self, msg_obj).tracking_id)
      end

      # Sender method to send request to adapter
      # @param [Octo::Message::Message] msg_obj Message Object
      def sender(msg_obj)
        connect(msg_obj)
        msg_hash = Octo::GaAdapter::Transformation.convert(msg_obj)
        Resque.enqueue(Octo::GaAdapter::Scheduler, msg_hash)
      end

    end

    # Transformation module to convert message into adapter specific form
    module Transformation

      # Converts Message object to adapter specific form
      # @param [Octo::Message::Message] msg_obj Message Object
      def convert(msg_obj)

      end
    end

    module Scheduler
      
      # Perform method of enqueue to perform GA operations
      def self.perform(msg_hash)
        send_pageview(msg_hash)
      end

      # Send PageViews to GA adapter
      def send_pageview(msg_hash)
        @tracker.pageview(msg_hash)
      end

    end
    
  end
end