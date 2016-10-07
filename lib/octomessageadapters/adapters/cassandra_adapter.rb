require 'octocore'

module Octo

  module CassandraAdapter
    include Octo::BaseAdapter

    ADAPTER_ID = 1

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
      eventName = msg.delete(:event_name)
      enterprise = checkEnterprise(msg)
      unless enterprise
        Octo.logger.info 'Unable to find enterprise. Something\'s wrong'
      end
      user = checkUser(enterprise, msg)

      register_api_event(enterprise, eventName)
      Octo::ApiTrack.new(customid: msg[:id],
                         created_at: Time.now,
                         json_dump: msg,
                         type: eventName).save!

      case eventName
      when 'app.init'
        Octo::AppInit.new(enterprise: enterprise,
                          created_at: Time.now,
                          userid: user.id).save!
        updateUserDeviceDetails(user, msg)
      when 'app.login'
        Octo::AppLogin.new(enterprise: enterprise,
                           created_at: Time.now,
                           userid: user.id).save!
        updateUserDeviceDetails(user, msg)
      when 'app.logout'
        event = Octo::AppLogout.new(enterprise: enterprise,
                                    created_at: Time.now,
                                    userid: user.id).save!
        updateUserDeviceDetails(user, msg)
      when 'page.view'
        page, categories, tags = checkPage(enterprise, msg)
        Octo::PageView.new(enterprise: enterprise,
                           created_at: Time.now,
                           userid: user.id,
                           routeurl: page.routeurl).save!
        updateUserDeviceDetails(user, msg)
      when 'productpage.view'
        product, categories, tags = checkProduct(enterprise, msg)
        Octo::ProductPageView.new(
                                 enterprise: enterprise,
                                 created_at: Time.now,
                                 userid: user.id,
                                 product_id: product.id).save!
        updateUserDeviceDetails(user, msg)
      when 'update.profile'
        checkUserProfileDetails(enterprise, user, msg)
        updateUserDeviceDetails(user, msg)
      when 'update.push_token'
        checkPushToken(enterprise, user, msg)
        checkPushKey(enterprise, msg)
      when 'funnel_update'
        checkRedisSession(enterprise,msg)
      end

      if eventName.startswith?('custom_')
        Octo::CustomEvents.new(
          enterprise: enterprise,
          created_at: Time.now,
          userid: user.id,
          msg_json: msg
        ).save!
      end
      msg
    end

    # Functionality of dispatcher method
    # @param [String] Adapter specific transformed message
    def self.dispatcher_method(t_msg)
      begin
        Octo::Callbacks.callback_update(t_msg)
      rescue Exception => e
        puts e.message
      end
    end

    class << self

      # Make an entry of Event type
      # @param [Octo::Enterprise] enterprise
      # @param [String] event_name Name of Event
      def register_api_event(enterprise, event_name)
        Octo::ApiEvent.findOrCreate({ enterprise_id: enterprise.id,
                                      eventname: event_name})
      end

      # Checks for msg[:rediskey] in redis, parses it and
      #  then calls updateFunnelTracker.
      # @param [Octo::Enterprise] enterprise The Enterprise object
      # @param [Hash] msg The message hash, MUST contain, :rediskey
      # @return [void]
      def checkRedisSession(enterprise,msg)
        sessionList = Cequel::Record.redis.lrange(msg[:rediskey],0,-1)
        Cequel::Record.redis.del(msg[:rediskey])
        sessionList.each_index{ |index|
          if index!=(sessionList.length-1)
            updateFunnelTracker(enterprise,sessionList[index],sessionList[index+1])
          end
        }
      end

      # Checks if transition from page1 -> page2 exists, then
      #  updates the value of its weight, else creates
      #  the transition with default weight 1. It also creates an
      #  entry for page 2 <- page 1, which helps us understand the
      #  incoming entries for a particular node.
      # @param [Octo::Enterprise] enterprise The Enterprise object
      # @param [string] page1 The url of page1
      # @param [string] page2 The url of page2
      # @return [void]
      def updateFunnelTracker(enterprise,page1,page2)
        args_to = {
            enterprise_id: enterprise.id,
            p1: page1,
            direction:1,
            p2: page2
        }
        args_from = {
            enterprise_id: enterprise.id,
            p1: page2,
            direction: 0,
            p2: page1
        }
        counters = {
            weight:1,
        }
        Octo::FunnelTracker.findOrCreateOrAdjust(args_to,counters)
        Octo::FunnelTracker.findOrCreateOrAdjust(args_from,counters)
      end

      # Creeate or Update Profile details of a user
      # @param [Octo::Enterprise] enterprise Object of enterprise model
      # @param [Octo::User] user Object of user model
      # @param [Hash] msg Hash of message
      # @return [Octo::UserProfileDetails] User Profile
      def checkUserProfileDetails(enterprise, user, msg)
        args = {
          user_id: user.id,
          user_enterprise_id: enterprise.id,
          email: msg[:profileDetails].fetch('email')
        }
        opts = {
          username: msg[:profileDetails].fetch('username', ''),
          gender: msg[:profileDetails].fetch('gender', ''),
          dob: msg[:profileDetails].fetch('dob', ''),
          alternate_email: msg[:profileDetails].fetch('alternate_email', ''),
          mobile: msg[:profileDetails].fetch('mobile', ''),
          extras: msg[:profileDetails].fetch('extras', '{}').to_s
        }
        Octo::UserProfileDetails.findOrCreateOrUpdate(args, opts)
      end

      # Checks for push tokens and creates or updates it
      # @param [Octo::Enterprise] enterprise The Enterprise object
      # @param [Octo::User] user The user to whom this token belongs to
      # @param [Hash] msg The message hash
      # @return [Octo::PushToken] The push token object corresponding to this user
      def checkPushToken(enterprise, user, msg)
        args = {
          user_id: user.id,
          user_enterprise_id: enterprise.id,
          push_type: msg[:pushType].to_i
        }
        opts = {
          pushtoken: msg[:pushToken]
        }
        Octo::PushToken.findOrCreateOrUpdate(args, opts)
      end

      # Checks for push keys and creates or updates it
      # @param [Octo::Enterprise] enterprise The Enterprise object
      # @param [Hash] msg The message hash
      # @return [Octo::PushKey] The push key object corresponding to this user
      def checkPushKey(enterprise, msg)
        args = {
          enterprise_id: enterprise.id,
          push_type: msg[:pushType].to_i
        }
        opts = {
          key: msg[:pushKey]
        }
        Octo::PushKey.findOrCreateOrUpdate(args, opts)
      end

      # Check if the enterprise exists. Create a new enterprise if it does
      #   not exist. This method makes sense because the enterprise authentication
      #   is handled by kong. Hence we can be sure that all these enterprises
      #   are valid.
      # @param [Hash] msg The message hash
      # @return [Octo::Enterprise] The enterprise object
      def checkEnterprise(msg)
        Octo::Enterprise.findOrCreate({id: msg[:enterpriseId]},
                                      {name: msg[:enterpriseName]})
      end

      # Checks for user and creates if not exists
      # @param [Octo::Enterprise] enterprise The Enterprise object
      # @param [Hash] msg The message hash
      # @return [Octo::User] The push user object corresponding to this user
      def checkUser(enterprise, msg)
        args = {
          enterprise_id: enterprise.id,
          id: msg[:userId]
        }
        Octo::User.findOrCreate(args)
      end

      # Updates location for a user
      # @param [Octo::User] user The user to whom this token belongs to
      # @param [Hash] msg The message hash
      # @return [Octo::UserLocationHistory] The location history object
      #   corresponding to this user
      def updateLocationHistory(user, msg)
        Octo::UserLocationHistory.new(
            user: user,
            latitude: msg[:phone].fetch('latitude', 0.0),
            longitude: msg[:phone].fetch('longitude', 0.0),
            created_at: Time.now).save!
      end

      # Updates user's device details
      # @param [Octo::User] user The user to whom this token belongs to
      # @param [Hash] msg The message hash
      def updateUserDeviceDetails(user, msg)
        args = {user_id: user.id,
                user_enterprise_id: user.enterprise.id}
        # Check Device Type
        if msg[:browser]
          updateUserBrowserDetails(args, msg)
        elsif msg[:phone]
          updateLocationHistory(user, msg)
          updateUserPhoneDetails(args, msg)
        end
      end

      # Updates user's phone details
      # @param [Hash] args The user details to whom this token belongs to
      # @param [Hash] msg The message hash
      # @return [Octo::UserPhoneDetails] The phone details object
      #   corresponding to this user
      def updateUserPhoneDetails(args, msg)
        opts = {deviceid: msg[:phone].fetch('deviceId', ''),
                manufacturer: msg[:phone].fetch('manufacturer', ''),
                model: msg[:phone].fetch('model', ''),
                os: msg[:phone].fetch('os', '')}
        Octo::UserPhoneDetails.findOrCreateOrUpdate(args, opts)
      end

      # Updates user's browser details
      # @param [Hash] args The user details to whom this token belongs to
      # @param [Hash] msg The message hash
      # @return [Octo::UserBrowserDetails] The browser details object
      #   corresponding to this user
      def updateUserBrowserDetails(args, msg)
        opts = {name: msg[:browser].fetch('name', ''),
                platform: msg[:browser].fetch('platform', ''),
                manufacturer: msg[:browser].fetch('manufacturer', ''),
                cookieid: msg[:browser].fetch('cookieid', '')}
        Octo::UserBrowserDetails.findOrCreateOrUpdate(args, opts)
      end

      # Checks the existence of a page and creates if not found
      # @param [Octo::Enterprise] enterprise The Enterprise object
      # @param [Hash] msg The message hash
      # @return [Array<Octo::Page, Array<Octo::Category>, Array<Octo::Tag>] The
      #   page object, array of categories objects and the array of tags
      #   object
      def checkPage(enterprise, msg)
        cats = checkCategories(enterprise, msg[:categories])
        tags = checkTags(enterprise, msg[:tags])

        args = {
          enterprise_id: enterprise.id,
          routeurl: msg[:routeUrl]
        }
        opts = {
          categories: Set.new(msg[:categories]),
          tags: Set.new(msg[:tags])
        }
        page = Octo::Page.findOrCreateOrUpdate(args, opts)
        [page, cats, tags]
      end

      # Checks for existence of a product and creates if not found
      # @param [Octo::Enterprise] enterprise The Enterprise object
      # @param [Hash] msg The message hash
      # @return [Array<Octo::Product, Array<Octo::Category>, Array<Octo::Tag>] The
      #   product object, array of categories objects and the array of tags
      #   object
      def checkProduct(enterprise, msg)
        categories = checkCategories(enterprise, msg[:categories])
        tags = checkTags(enterprise, msg[:tags])
        args = {
          enterprise_id: enterprise.id,
          id: msg[:productId]
        }
        opts = {
          categories: Set.new(msg[:categories]),
          tags: Set.new(msg[:tags]),
          price: msg[:price].to_f.round(2),
          name: msg[:productName],
          routeurl: msg[:routeUrl]
        }
        prod = Octo::Product.findOrCreateOrUpdate(args, opts)
        [prod, categories, tags]
      end

      # Checks for categories and creates if not found
      # @param [Octo::Enterprise] enterprise The enterprise object
      # @param [Array<String>] categories An array of categories to be checked
      # @return [Array<Octo::Category>] An array of categories object
      def checkCategories(enterprise, categories)
        if categories
          categories.collect do |category|
            Octo::Category.findOrCreate({enterprise_id: enterprise.id,
                                         cat_text: category})
          end
        end
      end

      # Checks for tags and creates if not found
      # @param [Octo::Enterprise] enterprise The enterprise object
      # @param [Array<String>] tags An array of tags to be checked
      # @return [Array<Octo::Tag>] An array of tags object
      def checkTags(enterprise, tags)
        if tags
          tags.collect do |tag|
            Octo::Tag.findOrCreate({enterprise_id: enterprise.id, tag_text: tag})
          end
        end
      end

    end

  end
end
