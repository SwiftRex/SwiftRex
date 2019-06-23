Pod::Spec.new do |s|
  s.name             = 'SwiftRex'
  s.version          = '0.5.0'
  s.summary          = 'SwiftRex is a Redux implementation on top of Combine, RxSwift or ReactiveSwift'
  s.description      = <<-DESC
                        SwiftRex is a framework that combines event-sourcing pattern and reactive programming (Combine, RxSwift or ReactiveSwift), providing a central state Store of which your ViewControllers or SwiftUI Views can observe and react to, as well as dispatching events coming from the user interaction.
                        This pattern is also known as 'Unidirectional Dataflow' or 'Redux'.
                        DESC
  s.homepage         = 'https://github.com/SwiftRex/SwiftRex'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Luiz Barbosa' => 'swiftrex@developercity.de' }
  s.source           = { :git => 'https://github.com/swiftrex/SwiftRex.git',
                         :tag => "v#{s.version}" }

  s.requires_arc     = true

  s.frameworks       = 'Foundation'
  s.default_subspec  = 'Core'

  s.subspec "Core" do |ss|
    ss.ios.deployment_target       = '8.0'
    ss.osx.deployment_target       = '10.10'
    ss.watchos.deployment_target   = '3.0'
    ss.tvos.deployment_target      = '9.0'
    ss.swift_version               = '5.0'

    ss.source_files  = "Sources/Common/"
    ss.framework  = "Foundation"
  end

  s.subspec "UsingCombine" do |ss|
    ss.ios.deployment_target       = '13.0'
    ss.osx.deployment_target       = '10.15'
    ss.watchos.deployment_target   = '6.0'
    ss.tvos.deployment_target      = '13.0'
    ss.swift_version               = '5.1'

    ss.source_files = "Sources/Combine/"
    ss.dependency "SwiftRex/Core"
  end

  s.subspec "UsingRxSwift" do |ss|
    ss.ios.deployment_target       = '8.0'
    ss.osx.deployment_target       = '10.10'
    ss.watchos.deployment_target   = '3.0'
    ss.tvos.deployment_target      = '9.0'
    ss.swift_version               = '5.0'

    ss.source_files = "Sources/RxSwift/"
    ss.dependency "SwiftRex/Core"
    ss.dependency 'RxSwift'
  end

  s.subspec "UsingReactiveSwift" do |ss|
    ss.ios.deployment_target       = '8.0'
    ss.osx.deployment_target       = '10.10'
    ss.watchos.deployment_target   = '3.0'
    ss.tvos.deployment_target      = '9.0'
    ss.swift_version               = '5.0'

    ss.source_files = "Sources/ReactiveSwift/"
    ss.dependency "SwiftRex/Core"
    ss.dependency 'ReactiveSwift'
  end
end
