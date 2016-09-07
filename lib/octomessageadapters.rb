require 'octocore/callbacks'

# Generic Adapter
require 'octomessageadapters/base_adapter'
require 'octomessageadapters/adapters'

module Octo
  # Message Adapters module
  module MessageAdapters
    # starts Adapter after Octo connection
    Octo::Callbacks.send(:after_connect, lambda {
      Octo::Adapter.after_connect
    })
  end
end