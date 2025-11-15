# Debugging API Topic Views Plugin

This guide will help you identify why the plugin isn't counting API views.

## Step 1: Verify Plugin Installation

Run this in your Rails console (`rails c` or `discourse console` in Docker):

```ruby
# Check if plugin is loaded
PluginRegistry.plugins.map(&:name)
# Should include "api-topic-views"

# Check if RequestLogger is available
defined?(ApiTopicViews::RequestLogger)
# Should return "constant"

# Check if the callback is registered
Middleware::RequestTracker.class_variable_get(:@@detailed_request_loggers)&.length
# Should be > 0 if registered
```

## Step 2: Verify Site Settings

```ruby
# Check if plugin is enabled
SiteSetting.api_topic_views_enabled
# Should return true

# Check if custom header is required
SiteSetting.api_topic_views_require_header
# Should return "" (empty) or your custom header name
```

**If `api_topic_views_enabled` is false:**
- Go to Admin → Settings → Plugins
- Search for "api_topic_views_enabled"
- Enable it

## Step 3: Test with Detailed Logging

Create a test script to monitor what's happening. Run this in Rails console:

```ruby
# Enable detailed logging
Rails.logger.level = Logger::DEBUG

# Create a test topic
test_topic = Topic.first
puts "Test Topic ID: #{test_topic.id}"
puts "Current views: #{test_topic.views}"

# Register a debug logger
debug_callback = ->(env, data) do
  Rails.logger.info("[DEBUG] Request received:")
  Rails.logger.info("  Path: #{env['PATH_INFO']}")
  Rails.logger.info("  is_api: #{data[:is_api]}")
  Rails.logger.info("  is_user_api: #{data[:is_user_api]}")
  Rails.logger.info("  status: #{data[:status]}")
  Rails.logger.info("  is_background: #{data[:is_background]}")
  Rails.logger.info("  is_crawler: #{data[:is_crawler]}")
  Rails.logger.info("  API_KEY_ENV set: #{!!env[Auth::DefaultCurrentUserProvider::API_KEY_ENV]}")
  Rails.logger.info("  USER_API_KEY_ENV set: #{!!env[Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV]}")
end

Middleware::RequestTracker.register_detailed_request_logger(debug_callback)
```

## Step 4: Make a Test API Request

Now make an API request to your Discourse instance. You need to use **proper API authentication**.

### Method A: Using Api-Key (System API Key)

```bash
# Get your API key from: Admin → API → Keys
# Create a new "All Users" key if needed

curl -v \
  -H "Api-Key: YOUR_API_KEY_HERE" \
  -H "Api-Username: system" \
  "https://your-discourse.com/t/TOPIC_ID.json"
```

### Method B: Using User API Key

```bash
curl -v \
  -H "User-Api-Key: YOUR_USER_API_KEY_HERE" \
  "https://your-discourse.com/t/TOPIC_ID.json"
```

**Important:** Replace:
- `YOUR_API_KEY_HERE` with your actual API key
- `TOPIC_ID` with the actual topic ID
- `your-discourse.com` with your Discourse URL

## Step 5: Check Logs

After making the request, check your logs:

```bash
# In Docker
./launcher logs app | grep -i "api-topic-views\|DEBUG"

# In development
tail -f log/development.log | grep -i "api-topic-views\|DEBUG"
```

Look for:
- `[DEBUG] Request received:` - Shows if the middleware is being called
- `[api-topic-views]` - Shows plugin-specific messages
- `is_api: true` or `is_user_api: true` - Confirms API detection

## Step 6: Check Job Queue

```ruby
# In Rails console
# Check if jobs were enqueued
Jobs::TrackApiTopicView.jobs.size
# Should be > 0 if jobs are queued

# Check last job
Jobs::TrackApiTopicView.jobs.last
# Should show topic_id, ip, user_id

# Manually run the job
job_args = Jobs::TrackApiTopicView.jobs.last["args"].first
Jobs::TrackApiTopicView.new.execute(job_args)

# Check if view count increased
test_topic.reload
test_topic.views
```

## Common Issues and Solutions

### Issue 1: Plugin Not Loaded

**Symptom:** `NameError: uninitialized constant ApiTopicViews`

**Solution:**
```bash
# Restart your Discourse instance
cd /var/discourse
./launcher restart app

# Or in development
bundle exec rails restart
```

### Issue 2: `is_api` is `false`

**Symptom:** Logs show `is_api: false` and `is_user_api: false`

**Solution:** You're not sending proper API authentication headers. Make sure you include:
- `Api-Key` AND `Api-Username` headers, OR
- `User-Api-Key` header

**DO NOT** just use session cookies - those don't count as API requests.

### Issue 3: Path Pattern Not Matching

**Symptom:** No job is enqueued even when `is_api: true`

**Test in console:**
```ruby
# Test the regex pattern
base_path = Discourse.base_path || ""
regex = %r{\A#{Regexp.escape(base_path)}/t/(?:[^/]+/)?(\d+)}

# Test your path
test_path = "/t/my-topic/123"
match = regex.match(test_path)
puts "Match: #{match.inspect}"
puts "Topic ID: #{match[1]}" if match
```

**Solution:** Ensure your API request URL follows one of these patterns:
- `/t/123.json` (topic ID only)
- `/t/slug/123.json` (with slug)
- `/t/slug/123` (without .json)

### Issue 4: Custom Header Required but Not Sent

**Symptom:** Jobs not enqueued despite `is_api: true`

**Check:**
```ruby
SiteSetting.api_topic_views_require_header
# If this returns something like "X-Count-As-View", you MUST send this header
```

**Solution:** Either:
1. Remove the custom header requirement (set to empty string), OR
2. Include the header in your API requests:
   ```bash
   curl -H "Api-Key: xxx" \
        -H "Api-Username: system" \
        -H "X-Count-As-View: true" \
        "https://your-discourse.com/t/123.json"
   ```

### Issue 5: Jobs Not Processing

**Symptom:** Jobs are enqueued but views don't increase

**Check Sidekiq:**
```ruby
# In Rails console
Sidekiq::Queue.all.map { |q| [q.name, q.size] }
# Check for jobs stuck in queue

# Check for failed jobs
Sidekiq::RetrySet.new.size
Sidekiq::DeadSet.new.size
```

**Solution:**
```bash
# Restart Sidekiq
cd /var/discourse
./launcher restart app
```

### Issue 6: Status Code Not 200

**Symptom:** Request succeeds but no tracking

**Check:** Make sure the API request returns status 200, not 301/302 redirects.

```bash
curl -I -H "Api-Key: xxx" -H "Api-Username: system" \
  "https://your-discourse.com/t/123.json"
# Look for "HTTP/1.1 200 OK"
```

## Quick Diagnostic Script

Run this all-in-one diagnostic:

```ruby
# === DIAGNOSTIC SCRIPT ===
puts "=== API Topic Views Plugin Diagnostic ==="
puts ""

# 1. Plugin loaded?
puts "1. Plugin loaded: #{defined?(ApiTopicViews::RequestLogger) ? 'YES ✓' : 'NO ✗'}"

# 2. Callback registered?
callbacks = Middleware::RequestTracker.class_variable_get(:@@detailed_request_loggers) rescue []
puts "2. Callbacks registered: #{callbacks&.length || 0}"

# 3. Settings
puts "3. Plugin enabled: #{SiteSetting.api_topic_views_enabled ? 'YES ✓' : 'NO ✗'}"
header_req = SiteSetting.api_topic_views_require_header.presence || "(none)"
puts "4. Required header: #{header_req}"

# 4. Test topic
test_topic = Topic.first
puts ""
puts "Test topic: #{test_topic.id}"
puts "Current views: #{test_topic.views}"
puts ""

# 5. Create API key instructions
api_key = ApiKey.where(revoked_at: nil).first
if api_key
  puts "Found API key: #{api_key.id}"
  puts ""
  puts "Test with this command:"
  puts "curl -H 'Api-Key: #{api_key.key}' \\"
  puts "     -H 'Api-Username: system' \\"
  puts "     '#{Discourse.base_url}/t/#{test_topic.id}.json'"
else
  puts "⚠️  No API keys found. Create one at: Admin → API → Keys"
end

puts ""
puts "6. Check queued jobs:"
puts "   Jobs queued: #{Jobs::TrackApiTopicView.jobs.size}"
```

## Still Not Working?

If you've tried all the above and it's still not working, please provide:

1. Output of the diagnostic script
2. The exact curl command you're using
3. The response headers from your API request
4. Any relevant log entries

Run this to gather info:

```ruby
# Generate debug report
report = {
  plugin_loaded: defined?(ApiTopicViews::RequestLogger),
  callbacks_count: (Middleware::RequestTracker.class_variable_get(:@@detailed_request_loggers) rescue [])&.length,
  settings: {
    enabled: SiteSetting.api_topic_views_enabled,
    required_header: SiteSetting.api_topic_views_require_header,
  },
  discourse_version: Discourse::VERSION::STRING,
  jobs_queued: Jobs::TrackApiTopicView.jobs.size,
  api_keys_count: ApiKey.where(revoked_at: nil).count
}

puts JSON.pretty_generate(report)
```

