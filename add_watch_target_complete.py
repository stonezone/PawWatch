#!/usr/bin/env python3
"""
Complete script to add watchOS 26.0 target to pawWatch.xcodeproj
Created: 2025-02-05
"""

import uuid
import sys

def generate_uuid():
    """Generate a 24-character UUID for Xcode"""
    return uuid.uuid4().hex.upper()[:24]

# Generate all required UUIDs
WATCH_TARGET_UUID = generate_uuid()
WATCH_PRODUCT_UUID = generate_uuid()
WATCH_SOURCES_UUID = generate_uuid()
WATCH_FRAMEWORKS_UUID = generate_uuid()
WATCH_RESOURCES_UUID = generate_uuid()
WATCH_GROUP_UUID = generate_uuid()
WATCH_CONFIG_DEBUG_UUID = generate_uuid()
WATCH_CONFIG_RELEASE_UUID = generate_uuid()
WATCH_CONFIG_LIST_UUID = generate_uuid()

# File references for Watch app source files
WATCH_APP_SWIFT_UUID = generate_uuid()
WATCH_CONTENT_VIEW_UUID = generate_uuid()
WATCH_ASSETS_UUID = generate_uuid()
WATCH_INFO_PLIST_UUID = generate_uuid()
WATCH_ENTITLEMENTS_UUID = generate_uuid()

print("Generated UUIDs:")
print(f"Watch Target: {WATCH_TARGET_UUID}")
print(f"Watch Product: {WATCH_PRODUCT_UUID}")

def main():
    project_path = "/Users/zackjordan/code/pawWatch-app/pawWatch.xcodeproj/project.pbxproj"
    
    print(f"\nReading project file: {project_path}")
    with open(project_path, 'r') as f:
        content = f.read()
    
    # 1. Add file references
    file_ref_insert = f'''\t\t{WATCH_PRODUCT_UUID} /* pawWatch Watch App.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "pawWatch Watch App.app"; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{WATCH_APP_SWIFT_UUID} /* pawWatchApp.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = pawWatchApp.swift; sourceTree = "<group>"; }};
\t\t{WATCH_CONTENT_VIEW_UUID} /* ContentView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; }};
\t\t{WATCH_ASSETS_UUID} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
\t\t{WATCH_INFO_PLIST_UUID} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
\t\t{WATCH_ENTITLEMENTS_UUID} /* pawWatch_Watch_App.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; name = pawWatch_Watch_App.entitlements; path = Config/pawWatch_Watch_App.entitlements; sourceTree = "<group>"; }};
/* End PBXFileReference section */'''
    
    content = content.replace(
        '/* End PBXFileReference section */',
        file_ref_insert
    )
    
    # 2. Add Watch app group
    watch_group = f'''\t\t{WATCH_GROUP_UUID} /* pawWatch Watch App */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{WATCH_APP_SWIFT_UUID} /* pawWatchApp.swift */,
\t\t\t\t{WATCH_CONTENT_VIEW_UUID} /* ContentView.swift */,
\t\t\t\t{WATCH_ASSETS_UUID} /* Assets.xcassets */,
\t\t\t\t{WATCH_INFO_PLIST_UUID} /* Info.plist */,
\t\t\t);
\t\t\tpath = "pawWatch Watch App";
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */'''
