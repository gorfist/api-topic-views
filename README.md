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

1. Hooks into Discourse's `Middleware::RequestTracker` to monitor requests
2. Identifies API requests to topic URLs (`/t/:slug/:id` or `/t/:id`)
3. Validates request criteria (API request, 200 status, not crawler, etc.)
4. Optionally checks for a required custom header
5. Enqueues a background job to increment topic view count
6. Tracks user visits for authenticated requests

## Configuration

All settings are configurable in the Admin Panel under **Settings > Plugins > api-topic-views**:

| Setting | Default | Description |
| --- | --- | --- |
| `api_topic_views_enabled` | `true` | Master switch to enable/disable the plugin |
| `api_topic_views_require_header` | `""` | Optional header name (e.g., `X-Count-As-View`) that must be present to count views. Leave empty to count all API requests |
| `api_topic_views_max_per_minute_per_ip` | `0` | Reserved for future rate limiting (currently not enforced) |

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

## Architecture

### Components

- **`plugin.rb`**: Plugin initialization and configuration
- **`lib/api_topic_views/request_logger.rb`**: Request interceptor and validator
- **`lib/api_topic_views/track_view_job.rb`**: Background job for view counting
- **`config/settings.yml`**: Plugin settings definitions
- **`config/locales/server.en.yml`**: Localization strings

### Request Flow

```
API Request → Middleware::RequestTracker 
  → RequestLogger.track_api_topic_view
  → Validate request criteria
  → Jobs.enqueue(:track_api_topic_view)
  → TrackApiTopicView job executes
  → Topic.views incremented
  → TopicUser.track_visit! (if authenticated)
```

## Troubleshooting

### Plugin not tracking views

1. Verify plugin is enabled: Admin → Settings → Plugins → `api_topic_views_enabled`
2. Check if you're making API requests (include `Api-Key` or `Api-Username` header)
3. Verify the request returns 200 status
4. If using custom header, ensure it's being sent with the correct name
5. Check logs for any errors: `tail -f logs/production.log | grep api-topic-views`

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