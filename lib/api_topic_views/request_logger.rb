# frozen_string_literal: true

module ApiTopicViews
  class RequestLogger
    def self.register!
      begin
        # Check if Middleware module exists first
        return unless defined?(Middleware)
        return unless defined?(Middleware::RequestTracker)
        return unless Middleware::RequestTracker.respond_to?(:register_detailed_request_logger)
        
        Middleware::RequestTracker.register_detailed_request_logger(
          ->(env, data) { track_api_topic_view(env, data) }
        )
      rescue NameError, NoMethodError => e
        # Silently fail during migrations or when middleware is not available
        Rails.logger.warn("[api-topic-views] Could not register request logger: #{e.message}") if defined?(Rails) && defined?(Rails.logger)
      end
    end

    def self.track_api_topic_view(env, data)
      return unless SiteSetting.api_topic_views_enabled

      return unless data[:is_api] || data[:is_user_api]

      return unless data[:status].to_i == 200
      return if data[:is_background]
      return if data[:is_crawler]

      required_header = SiteSetting.api_topic_views_require_header.to_s.strip
      if required_header.present?
        header_key = "HTTP_#{required_header.upcase.tr('-', '_')}"
        return unless env[header_key].present?
      end

      request = Rack::Request.new(env)
      path = request.path

      base_path = Discourse.base_path || ""
      regex = %r{\A#{Regexp.escape(base_path)}/t/(?:[^/]+/)?(\d+)}

      match = regex.match(path)
      return unless match

      topic_id = match[1].to_i
      return if topic_id <= 0

      ip = env["action_dispatch.remote_ip"].to_s
      ip = request.ip if ip.blank?

      current_user = lookup_user(env)

      if current_user
        TopicsController.defer_topic_view(topic_id, ip, current_user.id)
      else
        TopicsController.defer_topic_view(topic_id, ip)
      end
    rescue => e
      Rails.logger.warn(
        "[api-topic-views] Error tracking API topic view: #{e.class}: #{e.message}"
      )
    end

    def self.lookup_user(env)
      CurrentUser.lookup_from_env(env)
    rescue Discourse::InvalidAccess
      nil
    end
  end
end

