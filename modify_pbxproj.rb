#!/usr/bin/env ruby
# Script to add watchOS target to pawWatch.xcodeproj
# Uses Xcodeproj gem for safe project manipulation

require 'xcodeproj'

project_path = 'pawWatch.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Create Watch app target
watch_target = project.new_target(:watch2_app, 'pawWatch Watch App', :watchos, '26.0')

# Add source files to Watch target
watch_group = project.main_group.new_group('pawWatch Watch App', 'pawWatch Watch App')

# Add files
app_file = watch_group.new_file('pawWatchApp.swift')
content_file = watch_group.new_file('ContentView.swift')
assets = watch_group.new_file('Assets.xcassets')
info_plist = watch_group.new_file('Info.plist')

# Add to target
watch_target.add_file_references([app_file, content_file])
watch_target.resources_build_phase.add_file_reference(assets)

# Set build settings
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.stonezone.pawWatch.watchkitapp'
  config.build_settings['INFOPLIST_FILE'] = 'pawWatch Watch App/Info.plist'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '26.0'
  config.build_settings['SWIFT_VERSION'] = '6.2'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Config/pawWatch_Watch_App.entitlements'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

project.save

puts "✅ Successfully added Watch app target to #{project_path}"
