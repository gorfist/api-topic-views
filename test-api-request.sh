#!/bin/bash

# Test script for API Topic Views Plugin
# This script makes an API request to test if views are being tracked

# ======================
# CONFIGURATION
# ======================
# Set these values for your installation:

DISCOURSE_URL="https://your-discourse-url.com"  # Change this to your Discourse URL
API_KEY="your_api_key_here"                     # Get from Admin → API → Keys
TOPIC_ID="1"                                     # Change to a valid topic ID

# Optional: If you've set api_topic_views_require_header, uncomment and set this:
# CUSTOM_HEADER="X-Count-As-View"
# CUSTOM_HEADER_VALUE="true"

# ======================
# DO NOT EDIT BELOW
# ======================

echo "========================================"
echo "API Topic Views Plugin - Test Request"
echo "========================================"
echo ""

# Validate configuration
if [ "$DISCOURSE_URL" = "https://your-discourse-url.com" ]; then
    echo "❌ ERROR: Please edit this script and set your DISCOURSE_URL"
    exit 1
fi

if [ "$API_KEY" = "your_api_key_here" ]; then
    echo "❌ ERROR: Please edit this script and set your API_KEY"
    echo ""
    echo "Get your API key:"
    echo "1. Log in to Discourse as admin"
    echo "2. Go to: Admin → API → Keys"
    echo "3. Click 'New API Key'"
    echo "4. Select 'All Users' scope"
    echo "5. Copy the generated key"
    exit 1
fi

echo "Configuration:"
echo "  Discourse URL: $DISCOURSE_URL"
echo "  Topic ID: $TOPIC_ID"
echo "  API Key: ${API_KEY:0:10}..."
echo ""

# Build the URL
REQUEST_URL="${DISCOURSE_URL}/t/${TOPIC_ID}.json"

echo "Making API request to:"
echo "  $REQUEST_URL"
echo ""

# Build curl command
CURL_CMD="curl -v"
CURL_CMD="$CURL_CMD -H 'Api-Key: $API_KEY'"
CURL_CMD="$CURL_CMD -H 'Api-Username: system'"

# Add custom header if configured
if [ ! -z "$CUSTOM_HEADER" ]; then
    echo "Including custom header: $CUSTOM_HEADER"
    CURL_CMD="$CURL_CMD -H '$CUSTOM_HEADER: $CUSTOM_HEADER_VALUE'"
fi

CURL_CMD="$CURL_CMD '$REQUEST_URL'"

echo "========================================"
echo "Executing request..."
echo "========================================"
echo ""

# Execute the request
eval $CURL_CMD

echo ""
echo "========================================"
echo "Request complete!"
echo "========================================"
echo ""

echo "Next steps:"
echo "1. Check if the request returned HTTP 200 (see output above)"
echo "2. Check the logs for tracking confirmation:"
echo "   ./launcher logs app | grep 'api-topic-views'"
echo ""
echo "3. Verify the view count increased:"
echo "   ./launcher enter app"
echo "   rails c"
echo "   Topic.find($TOPIC_ID).views"
echo ""

echo "Expected log output:"
echo "  [api-topic-views] ✓ Tracking view for topic $TOPIC_ID"
echo "  [api-topic-views] ✓ Topic $TOPIC_ID views: X → Y"
echo ""

