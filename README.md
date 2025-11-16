# API Topic Views Plugin

A Discourse plugin that counts eligible API requests as topic views, allowing API traffic (mobile apps, partner integrations, etc.) to contribute to topic analytics just like regular web requests.

**Compatible with Discourse 3.2.0+**

## Features

- ✅ Tracks API requests as topic views
- ✅ Supports both API and User API requests
- ✅ Optional custom header requirement for fine-grained control
- ✅ Filters out crawlers and background requests
- ✅ User-aware tracking when authenticated
- ✅ Asynchronous job processing for performance
- ✅ Comprehensive test coverage

## How It Works

1. Hooks directly into Discourse's `TopicsController#show` action using `after_action` callback
2. Identifies API requests by checking for API keys or User API keys in headers/params
3. Validates request criteria (API request, 200 status, topic exists, etc.)
4. Optionally checks for a required custom header
5. Enqueues a background job to increment topic view count
6. Tracks user visits for authenticated requests

## Configuration

All settings are configurable in the Admin Panel under **Settings > Plugins > api-topic-views**:

| Setting | Default | Description |
| --- | --- | --- |
| `api_topic_views_enabled` | `true` | Master switch to enable/disable the plugin |
| `api_topic_views_require_header` | `""` | Optional header name (e.g., `X-Count-As-View`) that must be present to count views. Leave empty to count all API requests |
| `api_topic_views_max_per_minute_per_ip` | `0` | Maximum views per IP per topic per minute. Set to 0 to disable rate limiting |

### Custom Header Example

If you set `api_topic_views_require_header` to `X-Count-As-View`, your API clients must include this header:

```bash
curl -H "X-Count-As-View: true" \
     -H "Api-Key: your_api_key" \
     https://your-discourse.com/t/topic-slug/123.json
```

## Installation

### Docker-based Installation (Recommended)

1. Add to your `app.yml` in the plugins section:
   ```yaml
   hooks:
     after_code:
       - exec:
           cd: $home/plugins
           cmd:
             - git clone https://github.com/gorfist/api-topic-view.git
   ```

2. Rebuild your container:
   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

3. Enable the plugin in Admin Panel → Settings → Plugins

### Development Installation

1. Clone into your Discourse plugins directory:
   ```bash
   cd /path/to/discourse/plugins
   git clone https://github.com/gorfist/api-topic-view.git
   ```

2. Run bundle install:
   ```bash
   bundle install
   ```

3. Restart your development server

## Testing

Run the test suite:

```bash
bundle exec rake plugin:spec['api-topic-views']
```

## Compatibility

- **Discourse Version**: 3.2.0 or higher
- **Ruby**: 3.3.0+
- **Rails**: 8.0+

See `.discourse-compatibility` file for version pinning details.

## Localization

The plugin supports multiple languages:

- **English** (en) - Full support
- **Persian/Farsi** (fa_IR) - Full support

To add support for additional languages, create a file:
`config/locales/server.{language_code}.yml`

See `LOCALE_FIX.md` for details on adding new languages.

## Architecture

### Components

- **`plugin.rb`**: Plugin initialization and configuration
- **`lib/api_topic_views/request_logger.rb`**: Request interceptor and validator
- **`lib/api_topic_views/track_view_job.rb`**: Background job for view counting
- **`config/settings.yml`**: Plugin settings definitions
- **`config/locales/server.en.yml`**: Localization strings

### Request Flow

```
API Request → TopicsController#show 
  → after_action: track_api_topic_view
  → Validate request criteria (API key present, 200 status, etc.)
  → Jobs.enqueue(:track_api_topic_view)
  → TrackApiTopicView job executes
  → Topic.views incremented (with rate limiting)
  → TopicUser.track_visit! (if authenticated)
```

## Troubleshooting

### Plugin not tracking views

**Quick diagnostic steps:**

1. **Verify plugin is enabled**: Admin → Settings → Plugins → `api_topic_views_enabled` = true
2. **Check if you're making API requests**: You MUST include proper API authentication headers:
   - `Api-Key: your_key` AND `Api-Username: system`, OR
   - `User-Api-Key: your_user_key`
   
   ⚠️ **Regular session cookies don't count as API requests!**

3. **Verify the request returns 200 status** (not 301/302 redirect)
4. **Check the URL pattern**: Must be `/t/:id.json` or `/t/:slug/:id.json`
5. **If using custom header**, ensure it's being sent with the correct name

**Enable debug logging:**

Set environment variable in your `app.yml`:

```yaml
env:
  API_TOPIC_VIEWS_DEBUG: 'true'
```

Then rebuild and check logs:

```bash
./launcher rebuild app
./launcher logs app | grep api-topic-views
```

**Run the test script:**

Access your Rails console and run the included test script:

```bash
# Docker
./launcher enter app
rails c

# Then in console
load 'plugins/api-topic-view/TEST_SCRIPT.rb'
```

This will check:
- ✓ Plugin is loaded
- ✓ Callbacks are registered  
- ✓ Settings are correct
- ✓ Provide a test curl command

**Check detailed diagnostics:**

See [DEBUG.md](DEBUG.md) for comprehensive troubleshooting steps.

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Not using API auth** | Views not counting | Include `Api-Key` + `Api-Username` headers |
| **Wrong URL format** | No jobs queued | Use `/t/123.json` not `/t/123/` |
| **Custom header missing** | Jobs not created | Check `api_topic_views_require_header` setting |
| **Plugin disabled** | Nothing happens | Enable in Admin → Settings → Plugins |
| **Jobs not processing** | Jobs queued but views don't increase | Restart Sidekiq: `./launcher restart app` |

### Settings errors during rebuild

Ensure your `config/settings.yml` follows the correct format. Settings should be flat under the `plugins:` key, not nested under a sub-key.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - See repository for details

## Support

- GitHub Issues: https://github.com/gorfist/api-topic-view/issues
- Discourse Meta: https://meta.discourse.org/

## Changelog

### Version 0.3.0 (2025-11-16)

- 🔧 **BREAKING CHANGE**: Switched from middleware hooks to controller hooks for more reliable tracking
- ✨ Implemented direct `TopicsController` integration using `after_action` callback
- ✨ Added proper rate limiting functionality (was placeholder before)
- ✨ Added bot detection - skips tracking for bot users
- ✨ Added deleted topic check before incrementing views
- 🐛 Fixed view counting that wasn't working with middleware approach
- ⚡ Improved performance by using `update_all` for atomic view increments
- 📝 Updated documentation to reflect new architecture

**Migration Note**: This version uses a completely different tracking method. If you were using the previous version and it wasn't working, this should fix it!

### Version 0.2.1 (2025-11-15)

- 🐛 Enhanced debugging capabilities with detailed logging
- 📝 Added comprehensive troubleshooting documentation
- ✨ Added test script (TEST_SCRIPT.rb) for easy diagnostics
- ✨ Added debugging guide (DEBUG.md) and quick fix guide (QUICK_FIX.md)
- ✨ Added test-api-request.sh script for testing API calls
- 🔧 Improved error messages and logging in RequestLogger
- 🔧 Added view count logging in TrackApiTopicView job
- 📝 Enhanced README with common issues table

### Version 0.2.0 (2025-11-15)

- ✨ Modernized plugin structure for Discourse 3.2+
- ✨ Added background job processing for better performance
- ✨ Comprehensive test coverage
- ✨ Added `.discourse-compatibility` file
- 🐛 Fixed settings.yml structure issue
- 📝 Improved documentation
- 🔧 Cleaner error handling

### Version 0.1.0

- Initial release
- Basic API request tracking