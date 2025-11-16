# frozen_string_literal: true

module ::Jobs
  class TrackApiTopicView < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]
      ip = args[:ip]
      user_id = args[:user_id]

      debug_mode = ENV['API_TOPIC_VIEWS_DEBUG'] == 'true' || Rails.env.development?
      Rails.logger.info("[api-topic-views] Job executing for topic #{topic_id}, ip: #{ip}, user: #{user_id}") if debug_mode

      return unless topic_id && ip

      # Check rate limiting
      max_per_minute = SiteSetting.api_topic_views_max_per_minute_per_ip
      if max_per_minute > 0
        rate_limit_key = "api_topic_views:#{ip}:#{topic_id}"
        
        # Use Rails cache for rate limiting
        current_count = Discourse.redis.get(rate_limit_key).to_i
        
        if current_count >= max_per_minute
          Rails.logger.info("[api-topic-views] Rate limit exceeded for IP #{ip} on topic #{topic_id} (#{current_count}/#{max_per_minute})") if debug_mode
          return
        end
        
        # Increment counter with 60 second expiry
        if current_count == 0
          Discourse.redis.setex(rate_limit_key, 60, 1)
        else
          Discourse.redis.incr(rate_limit_key)
        end
        
        Rails.logger.info("[api-topic-views] Rate limit check passed: #{current_count + 1}/#{max_per_minute}") if debug_mode
      end

      # Find the topic
      topic = Topic.find_by(id: topic_id)
      unless topic
        Rails.logger.warn("[api-topic-views] Topic #{topic_id} not found")
        return
      end

      # Check if topic is deleted or closed
      if topic.deleted_at.present?
        Rails.logger.info("[api-topic-views] Topic #{topic_id} is deleted, skipping") if debug_mode
        return
      end

      # Get current view count
      old_views = topic.views

      # Increment view count using update_columns to bypass callbacks and validations
      Topic.where(id: topic_id).update_all("views = views + 1")
      
      # Reload to get the new count
      topic.reload
      
      Rails.logger.info("[api-topic-views] ✓ Topic #{topic_id} views: #{old_views} → #{topic.views}")

      # Track user visit if user is present
      if user_id
        user = User.find_by(id: user_id)
        if user && !user.bot?
          TopicUser.track_visit!(topic_id, user_id)
          Rails.logger.info("[api-topic-views] ✓ Tracked visit for user #{user_id}") if debug_mode
        end
      end
    rescue => e
      Rails.logger.error("[api-topic-views] Job failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      raise
    end
  end
end

