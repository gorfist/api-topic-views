# frozen_string_literal: true

module ApiTopicViews
  class RequestLogger
    def self.register!
      # Hook into TopicsController to track API requests
      ::TopicsController.class_eval do
        after_action :track_api_topic_view, only: [:show]

        private

        def track_api_topic_view
          debug_mode = ENV['API_TOPIC_VIEWS_DEBUG'] == 'true' || Rails.env.development?
          
          if debug_mode
            Rails.logger.info("[api-topic-views] ========== Request to #{request.path} ==========")
            Rails.logger.info("[api-topic-views] Plugin enabled: #{SiteSetting.api_topic_views_enabled}")
            Rails.logger.info("[api-topic-views] Response status: #{response.status}")
            Rails.logger.info("[api-topic-views] @topic present: #{@topic.present?}")
            Rails.logger.info("[api-topic-views] @topic.id: #{@topic&.id}")
          end
          
          return unless SiteSetting.api_topic_views_enabled
          
          # Only track API requests (check for API key or User API key)
          is_api_request = is_api? || is_user_api?
          
          if debug_mode
            Rails.logger.info("[api-topic-views] is_api?: #{is_api?}")
            Rails.logger.info("[api-topic-views] is_user_api?: #{is_user_api?}")
            Rails.logger.info("[api-topic-views] Combined is_api_request: #{is_api_request}")
            
            # Log API-related headers and params
            Rails.logger.info("[api-topic-views] HTTP_API_KEY present: #{request.headers['HTTP_API_KEY'].present?}")
            Rails.logger.info("[api-topic-views] HTTP_API_USERNAME present: #{request.headers['HTTP_API_USERNAME'].present?}")
            Rails.logger.info("[api-topic-views] HTTP_USER_API_KEY present: #{request.headers['HTTP_USER_API_KEY'].present?}")
            Rails.logger.info("[api-topic-views] params[:api_key] present: #{params[:api_key].present?}")
            Rails.logger.info("[api-topic-views] params[:api_username] present: #{params[:api_username].present?}")
            Rails.logger.info("[api-topic-views] current_user: #{current_user&.username}")
          end

          unless is_api_request
            Rails.logger.info("[api-topic-views] Not an API request, skipping") if debug_mode
            return
          end
          
          unless response.status == 200
            Rails.logger.info("[api-topic-views] Response status not 200: #{response.status}") if debug_mode
            return
          end

          # Get topic ID from @topic or from params
          topic_id = @topic&.id || params[:id] || params[:topic_id]
          
          if topic_id.blank?
            Rails.logger.info("[api-topic-views] No topic ID found in @topic or params") if debug_mode
            return
          end
          
          topic_id = topic_id.to_i
          if topic_id <= 0
            Rails.logger.info("[api-topic-views] Invalid topic ID: #{topic_id}") if debug_mode
            return
          end

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

          Rails.logger.info("[api-topic-views] ✓ Enqueueing view tracking for topic #{topic_id}, user: #{current_user&.id || 'anonymous'}, ip: #{ip}")

          # Queue job to track the view
          Jobs.enqueue(:track_api_topic_view, {
            topic_id: topic_id,
            ip: ip,
            user_id: current_user&.id
          })
        rescue => e
          Rails.logger.error("[api-topic-views] Error in track_api_topic_view: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        end

        def is_api?
          # Check if request is using an API key
          # In Discourse, API requests set these in the request.env
          has_api_key = request.env["HTTP_API_KEY"].present? || 
                        request.env["HTTP_API_USERNAME"].present? ||
                        params[:api_key].present? ||
                        params[:api_username].present?
          
          # Also check if current_user.api_key is present (set by Discourse middleware)
          has_api_key ||= current_user.present? && request.env["DISCOURSE_API_KEY"].present?
          
          has_api_key
        end

        def is_user_api?
          # Check if request is using User API key
          request.env["HTTP_USER_API_KEY"].present? ||
          request.env["USER_API_KEY"].present?
        end
      end

      Rails.logger.info("[api-topic-views] Plugin registered successfully using controller hooks")
    rescue => e
      Rails.logger.error("[api-topic-views] Failed to register plugin: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    end
  end
end

