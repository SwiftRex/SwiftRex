source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

ios_version = '8.0'
macos_version = '10.10'
tvos_version = '9.0'
watchos_version = '3.0'

pod 'SwiftLint'
pod 'Sourcery'

def rxswift
  pod 'RxSwift', '5.0.0', :inhibit_warnings => true
end

def reactiveswift
  pod 'ReactiveSwift', '6.0.0', :inhibit_warnings => true
end

def tests
  pod 'Nimble', '8.0.2'
end

###################
# RxSwift Targets #
###################

target 'SwiftRex iOS RxSwift' do
  platform :ios, ios_version
  rxswift
end

target 'SwiftRex watchOS RxSwift' do
  platform :watchos, watchos_version
  rxswift
end

target 'SwiftRex macOS RxSwift' do
  platform :macos, macos_version
  rxswift
end

target 'SwiftRex tvOS RxSwift' do
  platform :tvos, tvos_version
  rxswift
end

target 'UnitTests RxSwift' do
  platform :ios, ios_version
  rxswift
  tests
  pod 'RxBlocking', '5.0.0'
  pod 'RxTest', '5.0.0'
end

#########################
# ReactiveSwift Targets #
#########################

target 'SwiftRex iOS ReactiveSwift' do
  platform :ios, ios_version
  reactiveswift
end

target 'SwiftRex watchOS ReactiveSwift' do
  platform :watchos, watchos_version
  reactiveswift
end

target 'SwiftRex macOS ReactiveSwift' do
  platform :macos, macos_version
  reactiveswift
end

target 'SwiftRex tvOS ReactiveSwift' do
  platform :tvos, tvos_version
  reactiveswift
end

target 'UnitTests ReactiveSwift' do
  platform :ios, ios_version
  reactiveswift
  tests
end

##################
# Common Targets #
##################

target 'UnitTests SwiftRex' do
  platform :ios, ios_version
  tests
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
