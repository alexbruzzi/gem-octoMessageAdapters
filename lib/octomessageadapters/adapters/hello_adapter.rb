module Octo

  module HelloAdapter
    include Octo::BaseAdapter

    ADAPTER_ID = 0

    activate_if :activate_method

    transform :transform_method

    dispatcher :dispatcher_method

    # Functionality of activation method
    # @return [Bool] activate or not
    def self.activate_method
      true
    end

    # Functionality of transform method
    # @param [Hash] msg Message Hash
    # @return transformed message in required format
    def self.transform_method(msg)
      "HelloWorld"
    end

    # Functionality of dispatcher method
    # @param [String] Adapter specific transformed message
    def self.dispatcher_method(t_msg)
      puts t_msg
    end

  end
end
