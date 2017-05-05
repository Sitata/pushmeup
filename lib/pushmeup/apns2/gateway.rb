# require 'httparty'
# require 'json'
require 'jwt'
require 'net-http2'

module Pushmeup::APNS2
  class KeyNotSetException < StandardError; end
  class IdentifierNotSetException < StandardError; end

  class Gateway
    HOST = 'https://api.development.push.apple.com:443' # https://api.push.apple.com:443
    PORT = 443
    DEFAULT_TIMEOUT = 60
    JWT_ALGORITHM = 'ES256'
    PATH = "/3/device/"
    RETRYABLE_CODES = [ 429, 500, 503 ]


    def initialize(options={})
      @options = options
      @responses = Hash.new
      check_options

      @client = NetHttp2::Client.new(url, connect_timeout: DEFAULT_TIMEOUT)
    end

    def check_options
      raise KeyNotSetException, "You must set the 'apns2_private_key' option" unless apns2_private_key
      raise IdentifierNotSetException, "You must set the 'apns2_key_identifier' option" unless apns2_key_identifier
    end

    def url
      @url ||= "#{host}:#{port}"
    end

    def host
      @host ||= @options[:host] || Pushmeup.configuration.apns2_host || HOST
    end

    def port
      @port ||= @options[:port] || Pushmeup.configuration.apns2_port || PORT
    end

    def apns2_private_key
      @apns2_private_key ||= @options[:apns2_private_key] || Pushmeup.configuration.apns2_private_key
    end

    def apns2_key_identifier
      @apns2_key_identifier ||= @options[:apns2_key_identifier] || Pushmeup.configuration.apns2_key_identifier
    end

    def cleanup
      @client.close
    end

    def jwt_token
      payload = {
        iss: apns2_key_identifier,
        iat: Time.now.to_i
      }
      token = JWT.encode payload, apns2_private_key, 'ES256' {kid: apns2_key_identifier}
    end

    #Send notification
    def send_notification(device_token, message)
      n = Pushmeup::APNS::Notification.new(device_token, message)
      send_notifications([n])
    end

    def send_notifications(notifications)
      @responses = Hash.new

      @client.on(:error) { |err| mark_batch_retryable(Time.now + 10.seconds, err) }

      notifications.each do |n|
        prepare_async_post(n)
      end

      # Send all preprocessed requests at once
      @client.join
      @responses
    rescue Errno::ECONNREFUSED, SocketError => error
      #mark_batch_retryable(Time.now + 10.seconds, error)
      #raise
    rescue StandardError => error
      #mark_batch_failed(error)
      #raise
    end


    def prepare_async_post(notification)
      response = Hash.new

      http_request = @client.prepare_request(:post, full_url(notification),
        body:    body(notification),
        headers: headers(notification)
      )

      http_request.on(:headers) do |hdrs|
        response[:code] = hdrs[':status'].to_i
      end

      http_request.on(:body_chunk) do |body_chunk|
        next unless body_chunk.present?

        response[:failure_reason] = JSON.parse(body_chunk)['reason']
      end

      http_request.on(:close) { handle_response(notification, response) }

      @client.call_async(http_request)
    end

    def full_url(notification)
      "#{url}#{PATH}#{notification.device_token}"
    end

    def headers(notification)
      {
        "authorization"   => "bearer #{jwt_token}",
        "apns-id"         => notification.id,
        "apns-expiration" => notification.expiration,
        "apns-priority"   => notification.priority,
        "apns-topic"      => notification.topic,
        "authorization"   => notification.collapse_id
      }
    end

    def body(notification)
      hash = notification.body.as_json
      JSON.dump(hash).force_encoding(Encoding::BINARY)
    end

    def handle_response(notification, response)
      notification_resposne = @responses[notification.device_token] ||= Hash.new
      code = response[:code]
      notification_resposne[:status_code] = code

      case code
      when 200
        # do nothing
      when *RETRYABLE_CODES
        notification_resposne[:failure_reason] = response[:failure_reason]
      else
        notification_resposne[:failure_reason] = response[:failure_reason]
      end
    end



  end


end
