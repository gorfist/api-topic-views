# frozen_string_literal: true

module ApiTopicViews
  class RequestLogger
    def self.register!
      # Hook into TopicsController to track API requests
      ::TopicsController.class_eval do
        after_action :track_api_topic_view, only: [:show]

        private

        def track_api_topic_view
          return unless SiteSetting.api_topic_views_enabled
          
          # Only track API requests (check for API key or User API key)
          is_api_request = is_api? || is_user_api?
          
          debug_mode = ENV['API_TOPIC_VIEWS_DEBUG'] == 'true' || Rails.env.development?
          
          if debug_mode
            Rails.logger.info("[api-topic-views] Request: #{request.path}")
            Rails.logger.info("[api-topic-views] is_api_request: #{is_api_request}, response_status: #{response.status}")
            Rails.logger.info("[api-topic-views] Headers: #{request.headers.env.select { |k, v| k.start_with?('HTTP_') }.keys.join(', ')}")
          end

          return unless is_api_request
          return unless response.status == 200
          return if @topic.blank?

          # Check for required header if configured
          required_header = SiteSetting.api_topic_views_require_header.to_s.strip
          if required_header.present?
            header_value = request.headers[required_header]
            unless header_value.present?
              Rails.logger.info("[api-topic-views] Required header '#{required_header}' not present") if debug_mode
              return
            end
          end

          # Get IP address
          ip = request.remote_ip

          Rails.logger.info("[api-topic-views] ✓ Enqueueing view tracking for topic #{@topic.id}, user: #{current_user&.id || 'anonymous'}, ip: #{ip}")

          # Queue job to track the view
          Jobs.enqueue(:track_api_topic_view, {
            topic_id: @topic.id,
            ip: ip,
            user_id: current_user&.id
          })
        rescue => e
          Rails.logger.error("[api-topic-views] Error in track_api_topic_view: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        end

        def is_api?
          # Check if request is using an API key
          request.headers["HTTP_API_KEY"].present? || 
          request.headers["HTTP_API_USERNAME"].present? ||
          params[:api_key].present? ||
          params[:api_username].present?
        end

        def is_user_api?
          # Check if request is using User API key
          request.headers["HTTP_USER_API_KEY"].present? ||
          env["HTTP_USER_API_KEY"].present?
        end
      end

      Rails.logger.info("[api-topic-views] Plugin registered successfully using controller hooks")
    rescue => e
      Rails.logger.error("[api-topic-views] Failed to register plugin: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    end
  end
end

