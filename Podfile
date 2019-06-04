source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'SwiftLint'
pod 'Sourcery'

def platform_versions
  {
    rxswift: {
      ios: '8.0',
      macos: '10.10',
      tvos: '9.0',
      watchos: '3.0'
    },
    reactiveswift: {
      ios: '8.0',
      macos: '10.10',
      tvos: '9.0',
      watchos: '3.0'
    },
    combine: {
      ios: '13.0',
      macos: '10.15',
      tvos: '13.0',
      watchos: '6.0'
    }
  }
end

def rxswift
  pod 'RxSwift', '5.0.0', :inhibit_warnings => true
end

def reactiveswift
  pod 'ReactiveSwift', '6.0.0', :inhibit_warnings => true
end

def combine
end

###################
# RxSwift Targets #
###################

target 'SwiftRex iOS RxSwift' do
  platform :ios, platform_versions[:rxswift][:ios]
  rxswift
end

target 'SwiftRex watchOS RxSwift' do
  platform :watchos, platform_versions[:rxswift][:watchos]
  rxswift
end

target 'SwiftRex macOS RxSwift' do
  platform :macos, platform_versions[:rxswift][:macos]
  rxswift
end

target 'SwiftRex tvOS RxSwift' do
  platform :tvos, platform_versions[:rxswift][:tvos]
  rxswift
end

target 'UnitTests RxSwift' do
  platform :macos, platform_versions[:rxswift][:macos]
  rxswift
  pod 'RxBlocking', '5.0.0'
  pod 'RxTest', '5.0.0'
end

#########################
# ReactiveSwift Targets #
#########################

target 'SwiftRex iOS ReactiveSwift' do
  platform :ios, platform_versions[:reactiveswift][:ios]
  reactiveswift
end

target 'SwiftRex watchOS ReactiveSwift' do
  platform :watchos, platform_versions[:reactiveswift][:watchos]
  reactiveswift
end

target 'SwiftRex macOS ReactiveSwift' do
  platform :macos, platform_versions[:reactiveswift][:macos]
  reactiveswift
end

target 'SwiftRex tvOS ReactiveSwift' do
  platform :tvos, platform_versions[:reactiveswift][:tvos]
  reactiveswift
end

target 'UnitTests ReactiveSwift' do
  platform :macos, platform_versions[:reactiveswift][:macos]
  reactiveswift
end

###################
# Combine Targets #
###################

target 'SwiftRex iOS Combine' do
  platform :ios, platform_versions[:combine][:ios]
  combine
end

target 'SwiftRex watchOS Combine' do
  platform :watchos, platform_versions[:combine][:watchos]
  combine
end

target 'SwiftRex macOS Combine' do
  platform :macos, platform_versions[:combine][:macos]
  combine
end

target 'SwiftRex tvOS Combine' do
  platform :tvos, platform_versions[:combine][:tvos]
  combine
end

target 'UnitTests Combine' do
  platform :macos, platform_versions[:combine][:macos]
  combine
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
            config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
            config.build_settings['SWIFT_VERSION'] = "5.0"
            config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = "YES"

            if target.name == 'RxSwift' && config.name == 'Debug'
                config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['-D', 'TRACE_RESOURCES']
            end
        end
    end
end
