Pod::Spec.new do |s|
  s.name             = 'SwiftRex'
  s.version          = '0.5.0'
  s.summary          = 'SwiftRex is a Redux implementation on top of RxSwift or ReactiveSwift'
  s.description      = <<-DESC
                        SwiftRex is a framework that combines event-sourcing pattern and reactive programming (RxSwift or ReactiveSwift), providing a central state Store of which your ViewControllers can observe and react to, as well as dispatching events coming from the user interaction.
                        This pattern is also known as 'Unidirectional Dataflow' or 'Redux'.
                        DESC
  s.homepage         = 'https://github.com/SwiftRex/SwiftRex'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Luiz Barbosa' => 'swiftrex@developercity.de' }
  s.source           = { :git => 'https://github.com/swiftrex/SwiftRex.git',
                         :tag => "v#{s.version}" }

  s.requires_arc     = true

  s.ios.deployment_target       = '8.0'
  s.osx.deployment_target       = '10.10'
  s.watchos.deployment_target   = '3.0'
  s.tvos.deployment_target      = '9.0'
  s.swift_version = '5.0'

  s.frameworks    = 'Foundation'
  s.default_subspec   = 'UsingRxSwift'

  s.subspec 'UsingRxSwift' do |ss|
    ss.dependency 'RxSwift'
    ss.source_files  = 'Sources/{Common,RxSwift}/**/*.{swift,h,m}'
  end

  s.subspec 'UsingReactiveSwift' do |ss|
    ss.dependency 'ReactiveSwift'
    ss.source_files  = 'Sources/{Common,ReactiveSwift}/**/*.{swift,h,m}'
  end
end
