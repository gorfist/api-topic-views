# Discourse Dependencies Installation Guide for Windows 10

## Current Installation Status

### ✅ Already Installed:
- **Git**: 2.44.0.windows.1
- **Node.js**: v24.11.0
- **pnpm**: 10.22.0
- **Chocolatey**: 1.2.1

### ❌ Still Need to Install:
- Ruby (latest stable)
- Rails
- PostgreSQL
- SQLite
- Redis
- ImageMagick
- MailHog
- rbenv/asdf (Note: These are Unix-based; see alternatives below)

## Installation Instructions

### Option 1: Using Chocolatey (Recommended - Requires Admin)

1. **Open PowerShell as Administrator**:
   - Right-click on PowerShell
   - Select "Run as Administrator"

2. **Run the installation script**:
   ```powershell
   .\install-discourse-deps.ps1
   ```

   Or install packages individually:
   ```powershell
   choco install postgresql sqlite redis-64 imagemagick ruby mailhog -y
   ```

3. **After installation, install Rails**:
   ```powershell
   gem install rails
   ```

4. **Restart your terminal** to ensure PATH variables are updated.

### Option 2: Manual Installation

#### Ruby & Rails
- Download RubyInstaller from: https://rubyinstaller.org/downloads/
- Install the latest Ruby+Devkit version
- After installation, run: `gem install rails`

#### PostgreSQL
- Download from: https://www.postgresql.org/download/windows/
- Or use Chocolatey: `choco install postgresql -y`

#### SQLite
- Download from: https://www.sqlite.org/download.html
- Or use Chocolatey: `choco install sqlite -y`

#### Redis
- Download from: https://github.com/microsoftarchive/redis/releases
- Or use Chocolatey: `choco install redis-64 -y`

#### ImageMagick
- Download from: https://imagemagick.org/script/download.php#windows
- Or use Chocolatey: `choco install imagemagick -y`

#### MailHog
- Download from: https://github.com/mailhog/MailHog/releases
- Or use Chocolatey: `choco install mailhog -y`

## Important Notes

### rbenv/asdf on Windows
These tools are Unix-based and don't work natively on Windows. Options:

1. **Use RubyInstaller** (recommended for Windows)
   - RubyInstaller provides Ruby version management similar to rbenv
   - Download from: https://rubyinstaller.org/

2. **Use WSL2** (Windows Subsystem for Linux)
   - This provides a Linux environment where rbenv/asdf work natively
   - Recommended for Discourse development as Discourse is Linux-oriented
   - Install WSL2: `wsl --install`
   - Then follow Linux installation instructions

### Discourse Development on Windows
Discourse is primarily designed for Linux. For the best development experience:

1. **Use WSL2** (Recommended)
   - Provides native Linux environment
   - All tools work as intended
   - Better compatibility with Discourse

2. **Use Docker Desktop**
   - Discourse provides Docker-based development setup
   - Works well on Windows with Docker Desktop

## Verification

After installation, verify all tools are installed:

```powershell
git --version          # Should show: git version 2.x.x
ruby --version         # Should show: ruby 3.x.x
rails --version        # Should show: Rails 7.x.x
node --version         # Should show: v24.x.x
pnpm --version         # Should show: 10.x.x
psql --version         # Should show: psql (PostgreSQL) 18.x
sqlite3 --version      # Should show: 3.x.x
redis-cli --version    # Should show: redis-cli 7.x.x
magick --version       # Should show: ImageMagick version
mailhog --version      # Should show: MailHog version
```

## Next Steps

1. **Restart your terminal** after installations
2. **Verify all installations** using the commands above
3. **Consider setting up WSL2** for better Discourse development experience
4. **Follow Discourse setup guide**: https://github.com/discourse/discourse/blob/main/docs/DEVELOPER-ADVANCED.md


