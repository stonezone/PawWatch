#!/usr/bin/env python3
"""
Add watchOS 26.0 target to pawWatch.xcodeproj (ObjectVersion 77 format)
This script handles the modern Xcode 16 project format with file system sync
Created: 2025-02-05
"""

import uuid
import sys
import os

def generate_xcode_uuid():
    """Generate 24-character uppercase hex UUID for Xcode"""
    return uuid.uuid4().hex.upper()[:24]

# Generate all UUIDs
uuids = {
    'watch_target': generate_xcode_uuid(),
    'watch_product': generate_xcode_uuid(),
    'watch_sources': generate_xcode_uuid(),
    'watch_frameworks': generate_xcode_uuid(),
    'watch_resources': generate_xcode_uuid(),
    'watch_group': generate_xcode_uuid(),
    'watch_config_debug': generate_xcode_uuid(),
    'watch_config_release': generate_xcode_uuid(),
    'watch_config_list': generate_xcode_uuid(),
    'watch_entitlements_exception': generate_xcode_uuid(),
}

print("=== Adding watchOS Target to pawWatch ===\n")
print("Generated UUIDs:")
for name, uid in uuids.items():
    print(f"  {name}: {uid}")
print()

PROJECT_PATH = "/Users/zackjordan/code/pawWatch-app/pawWatch.xcodeproj/project.pbxproj"
