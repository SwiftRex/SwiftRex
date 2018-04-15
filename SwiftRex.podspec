Pod::Spec.new do |s|
  s.name             = "SwiftRex"
  s.version          = "0.1.0"
  s.summary          = "SwiftRex is a Redux implementation on top of RxSwift"
  s.description      = <<-DESC
                        SwiftRex is a framework that combines event-sourcing pattern and reactive programming (RxSwift), providing a central state Store of which your ViewControllers can observe and react to, as well as dispatching events coming from the user interaction.
                        This pattern is also known as "Unidirectional Dataflow" or "Redux".
                        DESC
  s.homepage         = "https://github.com/luizmb/SwiftRex"
  s.license          = { :type => "Apache 2.0", :file => "LICENSE" }
  s.author           = { "Luiz Barbosa" => "swiftrex@developercity.de" }
  s.source           = { :git => "https://github.com/luizmb/SwiftRex.git", :tag => s.version.to_s }

  s.requires_arc     = true

  s.ios.deployment_target       = '10.0'
  s.osx.deployment_target       = '10.10'
  s.watchos.deployment_target   = '3.0'
  s.tvos.deployment_target      = '10.0'

  s.source_files  = "Sources/**/*.{swift,h,m}"
  s.frameworks    = "Foundation"
  s.dependency "RxSwift", "~> 4.1"
end