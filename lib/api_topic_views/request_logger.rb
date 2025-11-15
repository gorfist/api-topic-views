# frozen_string_literal: true

module ApiTopicViews
  class RequestLogger
    def self.register!
      return unless defined?(Middleware::RequestTracker)
      return unless Middleware::RequestTracker.respond_to?(:register_detailed_request_logger)
      
      Middleware::RequestTracker.register_detailed_request_logger(
        ->(env, data) { track_api_topic_view(env, data) }
      )
    rescue => e
      Rails.logger.warn("[api-topic-views] Failed to register request logger: #{e.message}")
    end

    def self.track_api_topic_view(env, data)
      # Debug logging - can be disabled by setting environment variable
      debug_mode = ENV['API_TOPIC_VIEWS_DEBUG'] == 'true' || Rails.env.development?
      
      if debug_mode
        Rails.logger.info("[api-topic-views] Received request: #{env['PATH_INFO']}")
        Rails.logger.info("[api-topic-views] Data: is_api=#{data[:is_api]}, is_user_api=#{data[:is_user_api]}, status=#{data[:status]}")
      end

      unless SiteSetting.api_topic_views_enabled
        Rails.logger.info("[api-topic-views] Plugin disabled via settings") if debug_mode
        return
      end

      unless data[:is_api] || data[:is_user_api]
        Rails.logger.info("[api-topic-views] Not an API request") if debug_mode
        return
      end

      unless data[:status]&.to_i == 200
        Rails.logger.info("[api-topic-views] Status not 200: #{data[:status]}") if debug_mode
        return
      end

      if data[:is_background]
        Rails.logger.info("[api-topic-views] Background request, skipping") if debug_mode
        return
      end

      if data[:is_crawler]
        Rails.logger.info("[api-topic-views] Crawler request, skipping") if debug_mode
        return
      end

      # Check for required header if configured
      required_header = SiteSetting.api_topic_views_require_header.to_s.strip
      if required_header.present?
        header_key = "HTTP_#{required_header.upcase.tr('-', '_')}"
        unless env[header_key].present?
          Rails.logger.info("[api-topic-views] Required header '#{required_header}' not present") if debug_mode
          return
        end
      end

      request = Rack::Request.new(env)
      path = request.path

      # Extract topic ID from path
      base_path = Discourse.base_path || ""
      regex = %r{\A#{Regexp.escape(base_path)}/t/(?:[^/]+/)?(\d+)}
      match = regex.match(path)
      
      unless match
        Rails.logger.info("[api-topic-views] Path doesn't match topic pattern: #{path}") if debug_mode
        return
      end

      topic_id = match[1].to_i
      if topic_id <= 0
        Rails.logger.info("[api-topic-views] Invalid topic ID: #{topic_id}") if debug_mode
        return
      end

      # Get IP address
      ip = env["action_dispatch.remote_ip"].to_s
      ip = request.ip if ip.blank?

      # Get current user
      current_user = lookup_user(env)

      Rails.logger.info("[api-topic-views] ✓ Tracking view for topic #{topic_id}, user: #{current_user&.id || 'anonymous'}, ip: #{ip}")

      # Queue job to track the API topic view
      Jobs.enqueue(:track_api_topic_view, {
        topic_id: topic_id,
        ip: ip,
        user_id: current_user&.id
      })
    rescue => e
      Rails.logger.warn(
        "[api-topic-views] Error tracking API topic view: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      )
    end

    def self.lookup_user(env)
      CurrentUser.lookup_from_env(env)
    rescue Discourse::InvalidAccess, Discourse::ReadOnly
      nil
    end
  end
end

