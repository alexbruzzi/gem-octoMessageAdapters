require 'staccato'

module Octo
  module GaAdapter
    include Octo::AdapterSettings

    ADAPTER_ID = 0

    # callbacks_for :after_app_init, :after_app_login

    register self

    module ClassMethods

      # Create connection using GA Tracking ID
      def connect(msg_obj)
        @tracker = Staccato.tracker(settings(self, msg_obj).tracking_id)
      end

      def sender(msg_obj)
        connect(msg_obj)
      end

      def send_pageview
        @tracker.pageview({path: '/page-path', hostname: 'mysite.com', title: 'A Page!'})
      end

    end

    module Transformation
      def convert(msg_obj)

      end
    end
    
  end
end