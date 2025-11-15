# Quick Fix Guide - Plugin Not Counting Views

## Most Likely Issue: You're Not Using API Authentication

The plugin **only tracks requests that use API authentication**. Regular HTTP requests with session cookies **do not count**.

### ❌ This Won't Work:

```bash
# Regular request (browser-style)
curl "https://your-discourse.com/t/123.json"

# Request with only session cookie
curl -H "Cookie: _t=abc123..." "https://your-discourse.com/t/123.json"
```

### ✅ This WILL Work:

```bash
# System API Key
curl -H "Api-Key: YOUR_API_KEY" \
     -H "Api-Username: system" \
     "https://your-discourse.com/t/123.json"

# Or User API Key
curl -H "User-Api-Key: YOUR_USER_API_KEY" \
     "https://your-discourse.com/t/123.json"
```

## Your Setup (Backend → Hub)

Based on your description:
```
Client (App/Site) → Your Backend → Hub (Discourse)
```

**Your backend MUST use API authentication when calling the Hub.**

### Example: Python Backend

```python
import requests

# ✅ CORRECT - Using API authentication
response = requests.get(
    'https://hub-discourse.com/t/123.json',
    headers={
        'Api-Key': 'your_hub_api_key',
        'Api-Username': 'system'
    }
)
```

```python
# ❌ WRONG - No API authentication
response = requests.get('https://hub-discourse.com/t/123.json')
```

### Example: Node.js Backend

```javascript
// ✅ CORRECT
const response = await fetch('https://hub-discourse.com/t/123.json', {
  headers: {
    'Api-Key': 'your_hub_api_key',
    'Api-Username': 'system'
  }
});
```

## Step-by-Step Verification

### 1. Get Your API Key

On your Hub (Discourse instance):
1. Log in as admin
2. Go to: **Admin → API → Keys**
3. Click "New API Key"
4. Select:
   - User Level: **All Users**
   - Scope: **Global** (or customize as needed)
5. Click **Save**
6. Copy the generated key

### 2. Test the API Request

```bash
# Replace these values:
# - YOUR_HUB_URL: Your Discourse hub URL
# - YOUR_API_KEY: The key from step 1
# - TOPIC_ID: Any valid topic ID

curl -v \
  -H "Api-Key: YOUR_API_KEY" \
  -H "Api-Username: system" \
  "https://YOUR_HUB_URL/t/TOPIC_ID.json"
```

**Expected output:**
- Status: `HTTP/1.1 200 OK`
- Response: JSON topic data

### 3. Check the Logs

With enhanced logging (after updating the plugin):

```bash
# Docker
cd /var/discourse
./launcher logs app | grep "api-topic-views"

# Development
tail -f log/development.log | grep "api-topic-views"
```

**What you should see:**

✅ **If working:**
```
[api-topic-views] Received request: /t/123
[api-topic-views] Data: is_api=true, is_user_api=false, status=200
[api-topic-views] ✓ Tracking view for topic 123, user: anonymous, ip: 1.2.3.4
[api-topic-views] ✓ Topic 123 views: 10 → 11
```

❌ **If NOT working (no API auth):**
```
[api-topic-views] Received request: /t/123
[api-topic-views] Data: is_api=false, is_user_api=false, status=200
[api-topic-views] Not an API request
```

❌ **If plugin disabled:**
```
[api-topic-views] Received request: /t/123
[api-topic-views] Plugin disabled via settings
```

### 4. Run the Test Script

```bash
# On your Hub
cd /var/discourse
./launcher enter app
rails c

# In Rails console
load 'plugins/api-topic-view/TEST_SCRIPT.rb'
```

This will:
- Check if plugin is loaded ✓
- Check if settings are correct ✓
- Provide a working curl command ✓

### 5. Verify View Count

```bash
# In Rails console
topic_id = 123  # Replace with your topic ID

# Get current count
before = Topic.find(topic_id).views
puts "Before: #{before}"

# Make API request (in another terminal)
# curl -H "Api-Key: xxx" -H "Api-Username: system" "https://hub.com/t/123.json"

# Wait a few seconds for job to process
sleep 5

# Check new count
after = Topic.find(topic_id).reload.views
puts "After: #{after}"
puts "Increase: #{after - before}"
```

Expected: Count should increase by 1

## Still Not Working?

### Check These:

1. **Plugin enabled?**
   ```bash
   # In Rails console
   SiteSetting.api_topic_views_enabled
   # Should return: true
   ```

2. **Custom header required?**
   ```bash
   # In Rails console
   SiteSetting.api_topic_views_require_header
   # If not empty, you must send this header
   ```

3. **Jobs processing?**
   ```bash
   # In Rails console
   Jobs::TrackApiTopicView.jobs.size
   # If this grows but views don't increase, Sidekiq may be stuck
   # Solution: ./launcher restart app
   ```

4. **Enable debug mode:**
   
   Edit `/var/discourse/containers/app.yml`:
   ```yaml
   env:
     API_TOPIC_VIEWS_DEBUG: 'true'
   ```
   
   Then:
   ```bash
   ./launcher rebuild app
   ```

## Summary: 3 Critical Requirements

For the plugin to count a view, **ALL** of these must be true:

1. ✅ Request uses **API authentication** (Api-Key or User-Api-Key header)
2. ✅ Request is to a **topic endpoint** (`/t/:id` or `/t/:slug/:id`)
3. ✅ Request returns **status 200** (not redirect)

If any of these is false, the view will **not** be counted.

## Questions?

See the full debugging guide: [DEBUG.md](DEBUG.md)

