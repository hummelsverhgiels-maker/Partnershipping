# Однократный скрипт: добавляет виджет (WidgetKit) в проект iOS.
# Запуск: ruby ios/scripts/add_widget_target.rb   (из корня репозитория)
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner не найден' unless runner
exit 0 if project.targets.any? { |t| t.name == 'DaysOffWidget' }

ext = project.new_target(:app_extension, 'DaysOffWidget', :ios, '15.0')

group = project.main_group.new_group('DaysOffWidget', 'DaysOffWidget')
swift = group.new_file('DaysOffWidget.swift')
group.new_file('Info.plist')
group.new_file('DaysOffWidget.entitlements')
ext.add_file_references([swift])
ext.add_system_framework('WidgetKit')
ext.add_system_framework('SwiftUI')

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.partnershipping.partnershipping.DaysOffWidget'
  s['INFOPLIST_FILE'] = 'DaysOffWidget/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'DaysOffWidget/DaysOffWidget.entitlements'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['SKIP_INSTALL'] = 'YES'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
end

# Общее хранилище (App Group) для основного приложения
project.main_group.find_subpath('Runner', false)&.new_file('Runner.entitlements')
runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# Встроить виджет в приложение
runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Порядок фаз: встраивание виджета рядом с «Embed Frameworks», до скрипта Flutter
# «Thin Binary», иначе Xcode ругается на циклическую зависимость.
phases = runner.build_phases
phases.delete(embed)
idx = phases.index { |p| p.respond_to?(:name) && p.name == 'Embed Frameworks' } || phases.length
phases.insert(idx, embed)

project.save
puts 'Готово: виджет добавлен'
