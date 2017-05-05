module Pushmeup::APNS2
  class Notification
    attr_accessor :device_token,
                  :body, # APNS message body
                  # headers
                  # https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html#//apple_ref/doc/uid/TP40008194-CH11-SW17
                  :id,
                  :expiration,
                  :priority,
                  :topic, # typically bundle id
                  :collapse_id


    def initialize(device_token, body)
      self.device_token = device_token
      self.body         = body
      self.expiration   = 0
      self.id           = nil
      self.priority     = 10
      self.topic        = nil
      self.collapse_id  = nil

      raise "Body must be a hash." unless body.is_a?(Hash)
    end

  end
end
