#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SirenUA.xcodeproj'

# Create project
project = Xcodeproj::Project.create(project_path)

# Add main group
main_group = project.main_group

# Create SirenUA group
sirenua_group = main_group.new_group('SirenUA')

# Add all Swift files
Dir.glob('*.swift').each do |file|
  file_ref = sirenua_group.new_file(file)
  project.targets.first.add_file_references([file_ref])
end

# Add Info.plist
info_plist = sirenua_group.new_file('Info.plist')
project.targets.first.add_file_references([info_plist])

# Save project
project.save
puts "Xcode project created successfully!"
