# Changelog

All notable changes to the API Topic Views plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-11-15

### Added
- Background job processing (`Jobs::TrackApiTopicView`) for better performance
- Comprehensive RSpec test suite for request logger and job
- `.discourse-compatibility` file for version pinning
- Modern plugin structure following Discourse 3.2+ conventions
- Detailed architecture documentation in README
- Troubleshooting section in README
- Changelog file

### Changed
- Updated plugin to require Discourse 3.2.0+
- Modernized `plugin.rb` with cleaner initialization
- Improved error handling with proper logging
- Enhanced request logger with better code organization
- Updated README with comprehensive documentation

### Fixed
- **CRITICAL**: Fixed `settings.yml` structure causing "missing default value" error
  - Settings are now properly flat under `plugins:` key
  - Removed incorrect nested structure under `api_topic_views:` sub-key
- Removed excessive try/catch blocks that weren't needed
- Updated to use modern `require_relative` instead of `File.expand_path`

### Removed
- Removed overly defensive error handling that masked issues
- Cleaned up redundant safety checks

## [0.1.0] - Initial Release

### Added
- Basic API request tracking functionality
- Integration with Discourse's `Middleware::RequestTracker`
- Optional custom header requirement
- Site settings for plugin configuration
- Support for API and User API requests
- Filtering of crawlers and background requests
- User-aware tracking for authenticated requests

