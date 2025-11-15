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
      return unless SiteSetting.api_topic_views_enabled
      return unless data[:is_api] || data[:is_user_api]
      return unless data[:status]&.to_i == 200
      return if data[:is_background]
      return if data[:is_crawler]

      # Check for required header if configured
      required_header = SiteSetting.api_topic_views_require_header.to_s.strip
      if required_header.present?
        header_key = "HTTP_#{required_header.upcase.tr('-', '_')}"
        return unless env[header_key].present?
      end

      request = Rack::Request.new(env)
      path = request.path

      # Extract topic ID from path
      base_path = Discourse.base_path || ""
      regex = %r{\A#{Regexp.escape(base_path)}/t/(?:[^/]+/)?(\d+)}
      match = regex.match(path)
      return unless match

      topic_id = match[1].to_i
      return if topic_id <= 0

      # Get IP address
      ip = env["action_dispatch.remote_ip"].to_s
      ip = request.ip if ip.blank?

      # Get current user
      current_user = lookup_user(env)

      # Queue job to track the API topic view
      Jobs.enqueue(:track_api_topic_view, {
        topic_id: topic_id,
        ip: ip,
        user_id: current_user&.id
      })
    rescue => e
      Rails.logger.warn(
        "[api-topic-views] Error tracking API topic view: #{e.class}: #{e.message}"
      )
    end

    def self.lookup_user(env)
      CurrentUser.lookup_from_env(env)
    rescue Discourse::InvalidAccess, Discourse::ReadOnly
      nil
    end
  end
end

