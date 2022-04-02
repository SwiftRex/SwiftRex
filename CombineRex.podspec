Pod::Spec.new do |s|
  s.name             = 'CombineRex'
  s.version          = '0.8.12'
  s.summary          = 'SwiftRex is a Redux implementation on top of Combine, RxSwift or ReactiveSwift. This package implements SwiftRex using RxSwift.'
  s.description      = <<-DESC
                        SwiftRex is a framework that combines event-sourcing pattern and reactive programming (Combine, RxSwift or ReactiveSwift), providing a central state Store of which your ViewControllers or SwiftUI Views can observe and react to, as well as dispatching events coming from the user interaction.
                        This pattern is also known as 'Unidirectional Dataflow' or 'Redux'.
                        DESC
  s.homepage         = 'https://github.com/SwiftRex/SwiftRex'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Luiz Barbosa' => 'swiftrex@developercity.de' }
  s.source           = { :git => 'https://github.com/swiftrex/SwiftRex.git',
                         :tag => s.version }

  s.requires_arc     = true

  s.frameworks       = 'Foundation', 'Combine'

  s.ios.deployment_target       = '13.0'
  s.osx.deployment_target       = '10.15'
  s.watchos.deployment_target   = '6.0'
  s.tvos.deployment_target      = '13.0'
  s.swift_version               = '5.3'

  s.source_files = "Sources/CombineRex/**/*.swift"
  s.dependency 'SwiftRex', '~> 0.8.12'
end
