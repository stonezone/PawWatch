#!/bin/bash
# Script to add watchOS target to pawWatch project
# Created: 2025-02-05

set -e

PROJECT_DIR="/Users/zackjordan/code/pawWatch-app"
PROJECT_FILE="$PROJECT_DIR/pawWatch.xcodeproj"
WATCH_TARGET="pawWatch Watch App"

echo "Adding watchOS target to pawWatch project..."

# Navigate to project directory
cd "$PROJECT_DIR"

# Generate UUIDs for the new target components
WATCH_TARGET_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_PRODUCT_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_BUILD_PHASES_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_SOURCES_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_FRAMEWORKS_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_RESOURCES_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_CONFIG_DEBUG_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_CONFIG_RELEASE_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_CONFIG_LIST_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)
WATCH_GROUP_UUID=$(uuidgen | sed 's/-//g' | cut -c1-24)

echo "Generated UUIDs for new target components"
echo "Watch Target UUID: $WATCH_TARGET_UUID"

# We'll create an entitlements file for the Watch app
