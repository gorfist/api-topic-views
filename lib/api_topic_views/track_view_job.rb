# frozen_string_literal: true

module ::Jobs
  class TrackApiTopicView < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]
      ip = args[:ip]
      user_id = args[:user_id]

      return unless topic_id && ip

      # Find the topic
      topic = Topic.find_by(id: topic_id)
      return unless topic

      # Increment view count
      topic.views += 1
      topic.save(validate: false)

      # Track user visit if user is present
      if user_id
        TopicUser.track_visit!(topic_id, user_id)
      end
    end
  end
end

