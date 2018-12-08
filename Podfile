source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

def shared_pods
  pod 'RxSwift', '4.4.0', :inhibit_warnings => true
end

target 'SwiftRex iOS' do
  platform :ios, '8.0'
  shared_pods
end

target 'SwiftRex watchOS' do
  platform :watchos, '3.0'
  shared_pods
end

target 'SwiftRex macOS' do
  platform :macos, '10.10'
  shared_pods
end

target 'SwiftRex tvOS' do
  platform :tvos, '9.0'
  shared_pods
end

target 'UnitTests' do
  platform :macos, '10.10'
  shared_pods
  pod 'RxBlocking', '4.4.0'
  pod 'RxTest', '4.4.0'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
            config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
            config.build_settings['SWIFT_VERSION'] = "4.2"
            config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
            config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = "YES"

            if target.name == 'RxSwift' && config.name == 'Debug'
                config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['-D', 'TRACE_RESOURCES']
            end
        end
    end
end