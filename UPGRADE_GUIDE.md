# Upgrade Guide

This guide explains the changes made across versions and how to deploy them.

---

## v0.2.x → v0.3.0 (Current)

### Critical Changes - View Tracking Completely Rewritten

**Problem with v0.2.x**: The middleware-based approach (`Middleware::RequestTracker`) was unreliable and views were not being counted properly.

**Solution in v0.3.0**: Complete rewrite using direct controller hooks for guaranteed tracking.

### Major Changes

#### 1. New Tracking Architecture (BREAKING CHANGE)

**Before (v0.2.x)**:
- Used `Middleware::RequestTracker.register_detailed_request_logger`
- Relied on middleware intercepting requests
- Unreliable - often didn't trigger

**After (v0.3.0)**:
- Hooks directly into `TopicsController` using `after_action` callback
- Runs after every topic show action
- Guaranteed to trigger for every request
- More reliable API key detection

#### 2. Rate Limiting (NOW FUNCTIONAL)

**Before**: The `api_topic_views_max_per_minute_per_ip` setting existed but did nothing.

**After**: Fully functional rate limiting using Redis:
- Tracks views per IP per topic per minute
- Prevents abuse
- Set to `0` to disable (default)

#### 3. Enhanced View Increment Logic

**Improvements**:
- Uses atomic `update_all` for better performance
- Checks for deleted topics before incrementing
- Detects and skips bot users
- More robust error handling

#### 4. Better API Detection

**New methods** in `RequestLogger`:
- `is_api?` - Checks for API keys in headers and params
- `is_user_api?` - Checks for User API keys
- More comprehensive detection of API requests

### Deployment Instructions

#### Docker Installation (Recommended)

1. **Pull latest changes**:
   ```bash
   cd /var/discourse/plugins/api-topic-view
   git pull origin develop
   ```

2. **Rebuild container**:
   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

#### Manual Update

1. **Backup current version**:
   ```bash
   cd /var/discourse/plugins
   cp -r api-topic-view api-topic-view.backup
   ```

2. **Update files**:
   - `plugin.rb` - Version bumped to 0.3.0
   - `lib/api_topic_views/request_logger.rb` - Completely rewritten
   - `lib/api_topic_views/track_view_job.rb` - Enhanced with rate limiting
   - `README.md` - Updated documentation

3. **Rebuild**:
   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

### Verification Steps

1. **Check version**:
   - Go to Admin → Plugins
   - Verify version shows "0.3.0"

2. **Test API request tracking**:
   ```bash
   # Enable debug logging first
   # Add to app.yml: API_TOPIC_VIEWS_DEBUG: 'true'
   
   # Make an API request
   curl -H "Api-Key: YOUR_API_KEY" \
        -H "Api-Username: system" \
        https://your-discourse.com/t/123.json
   
   # Check logs
   ./launcher logs app | grep api-topic-views
   ```

3. **Verify view increment**:
   - Note the topic view count before the API request
   - Make the API request
   - Check the topic view count increased

### Breaking Changes

⚠️ **Architecture Changed**: This version uses a completely different tracking method.

**What this means**:
- Plugin should now work reliably where v0.2.x failed
- No configuration changes needed
- All existing settings remain the same
- Behavior is the same, just more reliable

**Migration**: No special migration needed. Just update and rebuild.

### New Features

✨ **Rate Limiting**: Set `api_topic_views_max_per_minute_per_ip` to a value > 0 to limit views per IP per topic per minute.

✨ **Bot Detection**: Automatically skips tracking for bot users.

✨ **Deleted Topic Check**: Won't increment views on deleted topics.

### Troubleshooting v0.3.0

#### Views still not counting

1. **Enable debug mode**:
   Add to your `app.yml`:
   ```yaml
   env:
     API_TOPIC_VIEWS_DEBUG: 'true'
   ```

2. **Check logs**:
   ```bash
   ./launcher logs app | grep api-topic-views
   ```

3. **Verify you're using API authentication**:
   - Must include `Api-Key` + `Api-Username` headers, OR
   - Must include `User-Api-Key` header
   - Regular session cookies don't count as API requests

4. **Check the response**:
   - Must be status 200
   - Must return topic data
   - Check `@topic` variable is set

#### Rate limiting blocking legitimate requests

If rate limiting is too restrictive:
- Go to Admin → Settings → Plugins
- Set `api_topic_views_max_per_minute_per_ip` to `0` (disable)
- Or increase the limit

### Rollback Plan

If you need to rollback to v0.2.1:

```bash
cd /var/discourse/plugins/api-topic-view
git checkout v0.2.1  # or the tag/branch for 0.2.1
cd /var/discourse
./launcher rebuild app
```

---

## v0.1 → v0.2.0

This guide explains the changes made to update the plugin for compatibility with Discourse 3.2+ and how to deploy them.

## Critical Fix Applied

### Settings.yml Structure Error (FIXED)

**Problem**: The original `config/settings.yml` had an incorrect nested structure:
```yaml
plugins:
  api_topic_views:           # ❌ This was being interpreted as a setting
    api_topic_views_enabled:
      default: true
```

**Solution**: Flattened the structure:
```yaml
plugins:
  api_topic_views_enabled:   # ✅ Correct - settings directly under plugins
    default: true
```

This was causing the error: `StandardError: The site setting 'api_topic_views' is missing default value`

## Major Changes

### 1. Plugin Initialization (plugin.rb)

**Before**:
- Excessive try/catch blocks
- Used `File.expand_path` with `__FILE__`
- Overly defensive error handling

**After**:
- Clean, modern initialization
- Uses `require_relative`
- Added `required_version: 3.2.0`
- Proper error handling without masking issues

### 2. Background Job Processing

**New Feature**: Added `lib/api_topic_views/track_view_job.rb`

Instead of synchronously tracking views, the plugin now:
1. Enqueues a background job (`Jobs::TrackApiTopicView`)
2. Job increments topic view count
3. Tracks user visits for authenticated requests

**Benefits**:
- Better performance (non-blocking)
- More reliable (retries on failure)
- Follows Discourse conventions

### 3. Request Logger Improvements

**Changes**:
- Cleaner guard clauses
- Better code organization with comments
- Modern Ruby conventions (safe navigation operator `&.`)
- Improved error messages with proper logging

### 4. Testing

**Added**:
- `spec/request_logger_spec.rb` - Tests for request interception
- `spec/track_view_job_spec.rb` - Tests for background job

Run tests with:
```bash
bundle exec rake plugin:spec['api-topic-views']
```

### 5. Version Compatibility

**Added**: `.discourse-compatibility` file for version pinning

This ensures users on older Discourse versions get compatible plugin versions.

### 6. Documentation

**Updated**:
- Comprehensive README with architecture, troubleshooting, and examples
- Added CHANGELOG.md
- Added LICENSE (MIT)
- Added .gitignore

## Deployment Instructions

### Option 1: Direct Update (If you have file access)

1. **Backup your current plugin**:
   ```bash
   cd /var/discourse/plugins
   cp -r api-topic-view api-topic-view.backup
   ```

2. **Pull the latest changes** (if using Git):
   ```bash
   cd /var/discourse/plugins/api-topic-view
   git pull origin main
   ```

   Or **manually replace files** if not using Git.

3. **Rebuild the container**:
   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

### Option 2: Docker Installation (Recommended)

1. **Edit your `app.yml`**:
   ```yaml
   hooks:
     after_code:
       - exec:
           cd: $home/plugins
           cmd:
             - git clone https://github.com/gorfist/api-topic-view.git
   ```

2. **Rebuild**:
   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

### Option 3: Manual File Update

If you're manually updating files, ensure you have these files in place:

**Required Files**:
- `plugin.rb` (updated)
- `config/settings.yml` (updated - CRITICAL FIX)
- `config/locales/server.en.yml` (unchanged)
- `lib/api_topic_views/request_logger.rb` (updated)
- `lib/api_topic_views/track_view_job.rb` (NEW)

**Optional but Recommended**:
- `.discourse-compatibility`
- `CHANGELOG.md`
- `LICENSE`
- `.gitignore`
- `spec/request_logger_spec.rb`
- `spec/track_view_job_spec.rb`

## Verification Steps

After deploying, verify the plugin is working:

1. **Check plugin is loaded**:
   - Go to Admin → Plugins
   - Verify "api-topic-views" appears in the list
   - Check version shows 0.2.0

2. **Verify settings**:
   - Go to Admin → Settings
   - Search for "api_topic_views"
   - You should see three settings:
     - `api_topic_views_enabled`
     - `api_topic_views_require_header`
     - `api_topic_views_max_per_minute_per_ip`

3. **Test functionality**:
   ```bash
   # Make an API request to a topic
   curl -H "Api-Key: YOUR_API_KEY" \
        -H "Api-Username: your_username" \
        https://your-discourse.com/t/test-topic/123.json
   
   # Check the topic view count increased
   ```

4. **Check logs** (if any issues):
   ```bash
   cd /var/discourse
   ./launcher logs app | grep api-topic-views
   ```

## Breaking Changes

### None - Fully Backwards Compatible

The plugin remains fully backwards compatible. All existing functionality is preserved:

- ✅ Same site settings (just fixed structure)
- ✅ Same behavior for tracking views
- ✅ Same header checking mechanism
- ✅ Same user detection

The only change users will notice is better performance due to background job processing.

## Troubleshooting

### Build fails with settings error

**Symptom**: `StandardError: The site setting 'api_topic_views' is missing default value`

**Solution**: Ensure your `config/settings.yml` has the flattened structure (see Critical Fix above)

### Plugin not loading

**Check**:
1. Discourse version is 3.2.0+ (check with `rails --version` in container)
2. All files are present in the plugin directory
3. Rebuild was successful (no errors in output)

### Views not being tracked

**Debug**:
1. Enable plugin: Admin → Settings → `api_topic_views_enabled` = true
2. Check you're making API requests (not regular browser requests)
3. Verify request returns 200 status
4. Check logs for errors:
   ```bash
   ./launcher logs app | grep "api-topic-views"
   ```

### Tests failing

**Run diagnostics**:
```bash
cd /var/discourse
./launcher enter app
cd plugins/api-topic-view
bundle exec rake plugin:spec['api-topic-views']
```

## Rollback Plan

If you need to rollback:

1. **Restore backup**:
   ```bash
   cd /var/discourse/plugins
   rm -rf api-topic-view
   mv api-topic-view.backup api-topic-view
   ```

2. **Rebuild**:
   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

## Questions or Issues?

- GitHub Issues: https://github.com/gorfist/api-topic-view/issues
- Discourse Meta: https://meta.discourse.org/

## Summary of Files Changed

| File | Status | Changes |
|------|--------|---------|
| `plugin.rb` | Modified | Modernized initialization, added job loading |
| `config/settings.yml` | **FIXED** | Flattened structure to fix critical error |
| `lib/api_topic_views/request_logger.rb` | Modified | Improved code, added job enqueueing |
| `lib/api_topic_views/track_view_job.rb` | **NEW** | Background job for view tracking |
| `.discourse-compatibility` | **NEW** | Version pinning support |
| `README.md` | Updated | Comprehensive documentation |
| `CHANGELOG.md` | **NEW** | Version history |
| `LICENSE` | **NEW** | MIT License |
| `.gitignore` | **NEW** | Git ignore patterns |
| `spec/request_logger_spec.rb` | **NEW** | Request logger tests |
| `spec/track_view_job_spec.rb` | **NEW** | Background job tests |

---

**Version**: 0.2.0  
**Date**: 2025-11-15  
**Compatible with**: Discourse 3.2.0+

