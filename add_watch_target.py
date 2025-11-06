#!/usr/bin/env python3
"""
Script to add watchOS target to pawWatch.xcodeproj
Created: 2025-02-05
"""

import uuid
import re

def generate_uuid():
    """Generate a 24-character UUID for Xcode"""
    return uuid.uuid4().hex.upper()[:24]

def read_pbxproj(path):
    """Read the project.pbxproj file"""
    with open(path, 'r') as f:
        return f.read()

def write_pbxproj(path, content):
    """Write the project.pbxproj file"""
    with open(path, 'w') as f:
        f.write(content)

def add_watch_target(pbxproj_content):
    """Add Watch target to the project"""
    
    # Generate UUIDs for all new objects
    watch_target_uuid = generate_uuid()
    watch_product_uuid = generate_uuid()
    watch_sources_uuid = generate_uuid()
    watch_frameworks_uuid = generate_uuid()
    watch_resources_uuid = generate_uuid()
    watch_group_uuid = generate_uuid()
    watch_config_debug_uuid = generate_uuid()
    watch_config_release_uuid = generate_uuid()
    watch_config_list_uuid = generate_uuid()
    
    print(f"Watch Target UUID: {watch_target_uuid}")
    print(f"Watch Product UUID: {watch_product_uuid}")
    
    # Add file reference for Watch app product
    file_ref_section = r'\/\* End PBXFileReference section \*\/'
    new_file_ref = f'''\t\t{watch_product_uuid} /* pawWatch Watch App.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "pawWatch Watch App.app"; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */'''
    
    pbxproj_content = re.sub(file_ref_section, new_file_ref, pbxproj_content)
    
    # Add Watch app to Products group
    products_section = r'(\t\t\t\t8B41F65C2DEDD0D6001A66F9 \/\* pawWatch\.xctest \*\/,)'
    new_product = f'''\t\t\t\t8B41F65C2DEDD0D6001A66F9 /* pawWatch.xctest */,
\t\t\t\t{watch_product_uuid} /* pawWatch Watch App.app */,'''
    
    pbxproj_content = re.sub(products_section, new_product, pbxproj_content)
    
    # Add Watch app group to main group
    main_group_section = r'(\t\t\t\t8B41F65F2DEDD0D6001A66F9 \/\* pawWatchUITests \*\/,)'
    new_group = f'''\t\t\t\t8B41F65F2DEDD0D6001A66F9 /* pawWatchUITests */,
\t\t\t\t{watch_group_uuid} /* pawWatch Watch App */,'''
    
    pbxproj_content = re.sub(main_group_section, new_group, pbxproj_content)
