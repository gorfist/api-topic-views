# frozen_string_literal: true

# Test script for API Topic Views Plugin
# Run this in Rails console: rails c
# Then: load 'plugins/api-topic-view/TEST_SCRIPT.rb'

puts "=" * 80
puts "API Topic Views Plugin - Test Script"
puts "=" * 80
puts ""

# Step 1: Check plugin is loaded
puts "1. Checking if plugin is loaded..."
if defined?(ApiTopicViews::RequestLogger)
  puts "   ✓ Plugin loaded successfully"
else
  puts "   ✗ Plugin NOT loaded"
  puts "   → Run: cd /var/discourse && ./launcher restart app"
  exit
end

# Step 2: Check if callback is registered
puts ""
puts "2. Checking if request tracker callback is registered..."
begin
  callbacks = Middleware::RequestTracker.class_variable_get(:@@detailed_request_loggers)
  if callbacks && callbacks.length > 0
    puts "   ✓ #{callbacks.length} callback(s) registered"
  else
    puts "   ✗ No callbacks registered"
    puts "   → The plugin may not have initialized properly"
  end
rescue => e
  puts "   ✗ Error checking callbacks: #{e.message}"
end

# Step 3: Check settings
puts ""
puts "3. Checking plugin settings..."
enabled = SiteSetting.api_topic_views_enabled rescue nil
if enabled.nil?
  puts "   ✗ Setting 'api_topic_views_enabled' not found"
  puts "   → The plugin may not be installed correctly"
elsif enabled
  puts "   ✓ Plugin is enabled"
else
  puts "   ✗ Plugin is DISABLED"
  puts "   → Enable at: Admin → Settings → Plugins → api_topic_views_enabled"
end

required_header = SiteSetting.api_topic_views_require_header.presence rescue nil
if required_header
  puts "   ⚠ Required header: '#{required_header}'"
  puts "   → You must include this header in API requests"
else
  puts "   ✓ No custom header required"
end

# Step 4: Get test topic
puts ""
puts "4. Finding test topic..."
test_topic = Topic.where(deleted_at: nil).first
if test_topic
  puts "   ✓ Test topic found: ID #{test_topic.id}"
  puts "   ✓ Current view count: #{test_topic.views}"
else
  puts "   ✗ No topics found in database"
  puts "   → Create a topic first"
  exit
end

# Step 5: Check for API keys
puts ""
puts "5. Checking for API keys..."
api_keys = ApiKey.where(revoked_at: nil)
if api_keys.any?
  api_key = api_keys.first
  puts "   ✓ Found #{api_keys.count} active API key(s)"
  puts ""
  puts "=" * 80
  puts "TEST COMMAND"
  puts "=" * 80
  puts ""
  puts "Run this curl command from your terminal:"
  puts ""
  
  header_flag = required_header ? " \\\n     -H '#{required_header}: true'" : ""
  
  puts "curl -v \\"
  puts "     -H 'Api-Key: #{api_key.key}' \\"
  puts "     -H 'Api-Username: system'#{header_flag} \\"
  puts "     '#{Discourse.base_url}/t/#{test_topic.id}.json'"
  puts ""
  puts "Expected: HTTP 200 response with topic data"
  puts "Then run: Topic.find(#{test_topic.id}).views"
  puts "Expected: View count should increase by 1"
else
  puts "   ✗ No active API keys found"
  puts ""
  puts "Create an API key:"
  puts "1. Go to: Admin → API → Keys"
  puts "2. Click 'New API Key'"
  puts "3. Select 'All Users' scope"
  puts "4. Click 'Save'"
  puts "5. Re-run this test script"
end

# Step 6: Manual test function
puts ""
puts "=" * 80
puts "MANUAL TEST FUNCTION"
puts "=" * 80
puts ""
puts "You can also test directly in the console:"
puts ""
puts "# Simulate an API request"
puts "env = {"
puts '  "REQUEST_METHOD" => "GET",'
puts "  \"PATH_INFO\" => \"/t/#{test_topic.id}\","
puts '  "action_dispatch.remote_ip" => "127.0.0.1"'
puts "}"
puts ""
puts "data = {"
puts "  is_api: true,"
puts "  is_user_api: false,"
puts "  status: 200,"
puts "  is_background: false,"
puts "  is_crawler: false"
puts "}"
puts ""
puts "# Track the view"
puts "ApiTopicViews::RequestLogger.track_api_topic_view(env, data)"
puts ""
puts "# Check if job was queued"
puts "Jobs::TrackApiTopicView.jobs.size"
puts ""
puts "# Process the job"
puts "Jobs::TrackApiTopicView.new.execute(Jobs::TrackApiTopicView.jobs.last['args'].first)"
puts ""
puts "# Check view count"
puts "Topic.find(#{test_topic.id}).reload.views"
puts ""

# Step 7: Check current job queue
puts "=" * 80
puts "CURRENT JOB QUEUE STATUS"
puts "=" * 80
puts ""
job_count = Jobs::TrackApiTopicView.jobs.size rescue 0
puts "Queued jobs: #{job_count}"
if job_count > 0
  puts ""
  puts "⚠ Warning: #{job_count} job(s) are waiting to be processed"
  puts "These may be from previous API requests"
  puts ""
  puts "To process them now:"
  puts "Jobs::TrackApiTopicView.jobs.each do |job|"
  puts "  Jobs::TrackApiTopicView.new.execute(job['args'].first)"
  puts "end"
end

puts ""
puts "=" * 80
puts "Test script complete!"
puts "=" * 80

