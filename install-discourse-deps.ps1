# Discourse Dependencies Installation Script for Windows 10
# Run this script as Administrator: Right-click PowerShell -> Run as Administrator

Write-Host "Installing Discourse Dependencies..." -ForegroundColor Green
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternatively, you can install packages manually:" -ForegroundColor Yellow
    Write-Host "  choco install postgresql sqlite redis-64 imagemagick ruby mailhog -y" -ForegroundColor Cyan
    Write-Host "  gem install rails" -ForegroundColor Cyan
    Write-Host "  npm install -g pnpm" -ForegroundColor Cyan
    exit 1
}

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    RefreshEnv
}

Write-Host "Updating Chocolatey..." -ForegroundColor Yellow
choco upgrade chocolatey -y

Write-Host ""
Write-Host "Installing packages..." -ForegroundColor Green
Write-Host ""

# Install PostgreSQL
Write-Host "Installing PostgreSQL..." -ForegroundColor Cyan
choco install postgresql -y --params '/Password:postgres'

# Install SQLite
Write-Host "Installing SQLite..." -ForegroundColor Cyan
choco install sqlite -y

# Install Redis
Write-Host "Installing Redis..." -ForegroundColor Cyan
choco install redis-64 -y

# Install ImageMagick
Write-Host "Installing ImageMagick..." -ForegroundColor Cyan
choco install imagemagick -y

# Install Ruby (using RubyInstaller)
Write-Host "Installing Ruby..." -ForegroundColor Cyan
choco install ruby -y

# Install Node.js (if not already installed)
Write-Host "Checking Node.js..." -ForegroundColor Cyan
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    choco install nodejs -y
}

# Install pnpm globally via npm
Write-Host "Installing pnpm..." -ForegroundColor Cyan
npm install -g pnpm

# Install Rails
Write-Host "Installing Rails..." -ForegroundColor Cyan
gem install rails

# Install MailHog
Write-Host "Installing MailHog..." -ForegroundColor Cyan
choco install mailhog -y

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "1. You may need to restart your terminal/PowerShell for PATH changes to take effect" -ForegroundColor White
Write-Host "2. For Discourse development, consider using WSL2 (Windows Subsystem for Linux)" -ForegroundColor White
Write-Host "   as Discourse is primarily designed for Linux environments" -ForegroundColor White
Write-Host "3. rbenv/asdf are Unix-based tools. On Windows, use RubyInstaller (installed above)" -ForegroundColor White
Write-Host "   or use WSL2 for a more native Discourse development experience" -ForegroundColor White
Write-Host ""
Write-Host "To verify installations, run:" -ForegroundColor Cyan
Write-Host "  git --version" -ForegroundColor White
Write-Host "  ruby --version" -ForegroundColor White
Write-Host "  rails --version" -ForegroundColor White
Write-Host "  node --version" -ForegroundColor White
Write-Host "  pnpm --version" -ForegroundColor White
Write-Host "  psql --version" -ForegroundColor White
Write-Host "  sqlite3 --version" -ForegroundColor White
Write-Host "  redis-cli --version" -ForegroundColor White
Write-Host "  magick --version" -ForegroundColor White

