# frozen_string_literal: true

module ::Jobs
  class TrackApiTopicView < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]
      ip = args[:ip]
      user_id = args[:user_id]

      debug_mode = ENV['API_TOPIC_VIEWS_DEBUG'] == 'true' || Rails.env.development?
      Rails.logger.info("[api-topic-views] Job executing for topic #{topic_id}") if debug_mode

      return unless topic_id && ip

      # Find the topic
      topic = Topic.find_by(id: topic_id)
      unless topic
        Rails.logger.warn("[api-topic-views] Topic #{topic_id} not found")
        return
      end

      # Get current view count
      old_views = topic.views

      # Increment view count
      topic.views += 1
      topic.save(validate: false)

      Rails.logger.info("[api-topic-views] ✓ Topic #{topic_id} views: #{old_views} → #{topic.views}")

      # Track user visit if user is present
      if user_id
        TopicUser.track_visit!(topic_id, user_id)
        Rails.logger.info("[api-topic-views] ✓ Tracked visit for user #{user_id}") if debug_mode
      end
    rescue => e
      Rails.logger.error("[api-topic-views] Job failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      raise
    end
  end
end

