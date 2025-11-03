Pod::Spec.new do |spec|

  spec.name         = "LottieFiles-dotLottie-iOS"
  spec.version      = "0.11.1"
  spec.summary      = "iOS player for .lottie and .json files."

  spec.description  = <<-DESC
Currently this package supports a mimimum iOS version of 13+ for iPhone and iPad. MacOS is supported for versions 11.0 and upwards.
This is a temporary pod name until we regain ownership of dotLottie-iOS. Use this pod for the latest updates from LottieFiles.
                   DESC

  spec.homepage     = "https://github.com/LottieFiles/dotlottie-ios"
  spec.source       = { :git => "https://github.com/LottieFiles/dotlottie-ios.git", :tag => "v#{spec.version}" }
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.authors      = {
    "Sam Osborne" => "sam@lottiefiles.com",
    "Evandro Hofffmann" => "evandro@lottiefiles.com",
    "Abdelrahman Ashraf" => "abdelrahman@lottiefiles.com"
  }

  spec.module_name = 'DotLottie'

  spec.swift_version = '5.0'
  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "11.0"

  spec.source_files = 'Sources/DotLottie/**/*.{swift,h,m}'
  spec.vendored_frameworks = 'Sources/DotLottieCore/DotLottiePlayer.xcframework'

  spec.requires_arc = true

end
