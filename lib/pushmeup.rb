require "pushmeup/version"
require "pushmeup/apple"
require "pushmeup/android"
require "pushmeup/amazon"


module Pushmeup

  class << self

    def configuration
      @configuration ||= Configuration.new
    end

    def configuration=(config)
      @configuration = config
    end

    def configure
      yield(configuration)
    end

  end

  class Configuration
    attr_accessor :apns_host, :apns_port, :apns_pem, :apns_pass,
                  :gcm_host, :gcm_key,
                  :fire_client_id, :fire_client_secret,
                  :apns2_host, :apns2_port, :apns2_private_key, :apns2_key_identifier
  end


end
