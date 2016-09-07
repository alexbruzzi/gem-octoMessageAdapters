require 'octocore/callbacks'

# Generic Adapter
require 'messageadapters/base_adapter'
require 'messageadapters/adapters'

module Octo
  # Message Adapters module
  module MessageAdapters
    # starts Adapter after Octo connection
    Octo::Callbacks.send(:after_connect, lambda {
      Octo::Adapter.after_connect
    })
  end
end