# frozen_string_literal: true
# API Topic Views Plugin - Diagnostic Test Script
# Run this in Rails console: load 'plugins/api-topic-views/TEST_SCRIPT.rb'

puts "\n" + "="*80
puts "API TOPIC VIEWS PLUGIN - DIAGNOSTIC TEST"
puts "="*80 + "\n"

# Test 1: Check if plugin is loaded
puts "1. Checking if plugin is loaded..."
plugin = Discourse.plugins.find { |p| p.name == 'api-topic-views' }
if plugin
  puts "   ✓ Plugin loaded: api-topic-views"
  puts "   ✓ Version: #{plugin.metadata.version}"
else
  puts "   ✗ Plugin NOT loaded!"
  puts "   → Check if plugin directory exists in plugins/"
  puts "   → Try rebuilding: cd /var/discourse && ./launcher rebuild app"
  exit
end

# Test 2: Check settings
puts "\n2. Checking plugin settings..."
begin
  enabled = SiteSetting.api_topic_views_enabled
  puts "   ✓ api_topic_views_enabled: #{enabled}"
  
  header = SiteSetting.api_topic_views_require_header
  puts "   ✓ api_topic_views_require_header: '#{header}' #{header.blank? ? '(none required)' : ''}"
  
  rate_limit = SiteSetting.api_topic_views_max_per_minute_per_ip
  puts "   ✓ api_topic_views_max_per_minute_per_ip: #{rate_limit} #{rate_limit == 0 ? '(disabled)' : ''}"
  
  unless enabled
    puts "\n   ⚠ WARNING: Plugin is DISABLED!"
    puts "   → Enable it in Admin → Settings → Plugins → api_topic_views_enabled"
  end
rescue => e
  puts "   ✗ Error loading settings: #{e.message}"
  puts "   → Settings may not be properly defined"
end

# Test 3: Check if controller hook is registered
puts "\n3. Checking controller hooks..."
begin
  # Check if TopicsController has our callback
  callbacks_exist = TopicsController._process_action_callbacks.any? do |callback|
    callback.filter.to_s.include?('track_api_topic_view')
  end
  
  if callbacks_exist
    puts "   ✓ Controller hook registered (after_action: track_api_topic_view)"
  else
    puts "   ⚠ Controller hook may not be registered"
    puts "   → This could mean the plugin didn't initialize properly"
  end
  
  # Check if methods exist
  if TopicsController.private_method_defined?(:track_api_topic_view)
    puts "   ✓ track_api_topic_view method exists"
  else
    puts "   ✗ track_api_topic_view method NOT found"
  end
  
  if TopicsController.private_method_defined?(:is_api?)
    puts "   ✓ is_api? method exists"
  else
    puts "   ✗ is_api? method NOT found"
  end
rescue => e
  puts "   ✗ Error checking hooks: #{e.message}"
end

# Test 4: Check job is defined
puts "\n4. Checking background job..."
begin
  if defined?(Jobs::TrackApiTopicView)
    puts "   ✓ TrackApiTopicView job is defined"
  else
    puts "   ✗ TrackApiTopicView job NOT defined"
  end
rescue => e
  puts "   ✗ Error checking job: #{e.message}"
end

# Test 5: Check Redis connectivity
puts "\n5. Checking Redis connectivity..."
begin
  test_key = "api_topic_views:test:#{Time.now.to_i}"
  Discourse.redis.setex(test_key, 5, "test_value")
  value = Discourse.redis.get(test_key)
  Discourse.redis.del(test_key)
  
  if value == "test_value"
    puts "   ✓ Redis is working (needed for rate limiting)"
  else
    puts "   ⚠ Redis test failed"
  end
rescue => e
  puts "   ✗ Redis error: #{e.message}"
  puts "   → Rate limiting may not work"
end

# Test 6: Find a test topic
puts "\n6. Finding a topic for testing..."
topic = Topic.where(deleted_at: nil).where.not(archetype: 'private_message').first
if topic
  puts "   ✓ Found topic: ID=#{topic.id}, Title='#{topic.title.truncate(50)}'"
  puts "   ✓ Current views: #{topic.views}"
else
  puts "   ⚠ No topics found"
  puts "   → Create a topic first to test view tracking"
end

# Test 7: Check for API keys
puts "\n7. Checking for API keys..."
begin
  api_keys_count = ApiKey.where(revoked_at: nil).count
  if api_keys_count > 0
    puts "   ✓ Found #{api_keys_count} active API key(s)"
    
    # Show a sample key (first 10 chars only)
    sample_key = ApiKey.where(revoked_at: nil).first
    if sample_key
      puts "   ✓ Sample key ID: #{sample_key.id}, User: #{sample_key.user&.username || 'system'}"
      puts "     Key starts with: #{sample_key.key[0..9]}..."
    end
  else
    puts "   ⚠ No API keys found"
    puts "   → Create one in Admin → API → Keys"
  end
rescue => e
  puts "   ✗ Error checking API keys: #{e.message}"
end

# Test 8: Environment check
puts "\n8. Environment information..."
puts "   • Rails version: #{Rails.version}"
puts "   • Discourse version: #{Discourse::VERSION::STRING}"
puts "   • Ruby version: #{RUBY_VERSION}"
puts "   • Environment: #{Rails.env}"

debug_mode = ENV['API_TOPIC_VIEWS_DEBUG'] == 'true' || Rails.env.development?
puts "   • Debug logging: #{debug_mode ? 'ENABLED' : 'DISABLED'}"
unless debug_mode
  puts "     → Enable debug logging by adding API_TOPIC_VIEWS_DEBUG: 'true' to app.yml"
end

# Summary and test command
puts "\n" + "="*80
puts "SUMMARY"
puts "="*80

if plugin && enabled && topic
  puts "\n✓ Plugin appears to be working!"
  puts "\nTo test view tracking, run this command from your terminal:\n\n"
  
  base_url = Discourse.base_url
  api_key = ApiKey.where(revoked_at: nil).first
  
  if api_key
    username = api_key.user&.username || 'system'
    puts "curl -v \\"
    puts "  -H 'Api-Key: #{api_key.key}' \\"
    puts "  -H 'Api-Username: #{username}' \\"
    puts "  '#{base_url}/t/#{topic.id}.json'"
    puts "\n"
    puts "Before running, note the current view count: #{topic.views}"
    puts "After running, check if it increased to: #{topic.views + 1}"
    puts "\nTo see detailed logs:"
    puts "  cd /var/discourse"
    puts "  ./launcher logs app | grep api-topic-views"
  else
    puts "⚠ Cannot generate test command - no API key found"
    puts "→ Create an API key in Admin → API → Keys first"
  end
else
  puts "\n⚠ Issues detected - review the output above"
  
  unless plugin
    puts "  • Plugin is not loaded"
  end
  
  unless enabled
    puts "  • Plugin is disabled - enable in Admin → Settings"
  end
  
  unless topic
    puts "  • No topics available for testing"
  end
end

puts "\n" + "="*80
puts "For more help, see:"
puts "  • README.md in the plugin directory"
puts "  • UPGRADE_GUIDE.md for version-specific information"
puts "  • https://github.com/gorfist/api-topic-views/issues"
puts "="*80 + "\n"
