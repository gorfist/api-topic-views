# frozen_string_literal: true

# name: api-topic-views
# about: Count selected API requests as topic views
# version: 0.3.0
# authors: Discourse Community
# url: https://github.com/gorfist/api-topic-view
# required_version: 3.2.0

enabled_site_setting :api_topic_views_enabled

after_initialize do
  require_relative "lib/api_topic_views/track_view_job"
  require_relative "lib/api_topic_views/request_logger"
  
  ApiTopicViews::RequestLogger.register!
end

