require 'octocore'

module Octo

  module RedisAdapter
    include Octo::BaseAdapter

    ADAPTER_ID = 0

    activate_if :activate_method

    transform :transform_method

    dispatcher :dispatcher_method

    attr_reader :redis

    # Functionality of activation method
    # @return [Bool] activate or not
    def self.activate_method
      # Establish connection to redis server
      default_config = {
        host: '127.0.0.1', port: 6379
      }
      @redis = Redis.new(Octo.get_config(:redis, default_config))
      true
    end

    # Functionality of transform method
    # @param [Hash] msg Message Hash
    # @return transformed message in required format
    def self.transform_method(msg)
      msg
    end

    # Functionality of dispatcher method
    # @param [String] Adapter specific transformed message
    def self.dispatcher_method(t_msg)
      @redis.publish('message', t_msg)
    end

  end
end
