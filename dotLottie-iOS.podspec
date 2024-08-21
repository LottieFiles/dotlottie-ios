#
#  Be sure to run `pod spec lint dotLottie-iOS.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  spec.name         = "dotLottie-iOS"
  spec.version      = "0.6.2"
  spec.summary      = "iOS player for .lottie and .json files."

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  spec.description  = <<-DESC
Currently this package supports a mimimum iOS version of 15.4+ for iPhone and iPad. MacOS is supported for versions 12.0 and upwards.
                   DESC

  spec.homepage     = "https://github.com/LottieFiles/dotlottie-ios"
  spec.source       = { :git => "https://github.com/LottieFiles/dotlottie-ios.git", :tag => "#{spec.version}" }
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.authors            = {
    "Sam Osborne" => "sam@lottiefiles.com",
    "Evandro Hofffmann" => "evandro@lottiefiles.com"
  }

  spec.source_files = 'Sources/**/*'

  spec.module_name = 'dotLottie'

  #  When using multiple platforms
  spec.swift_version = '5.0'
  spec.ios.deployment_target = "15.4"
  spec.osx.deployment_target = "12.0"
  # spec.watchos.deployment_target = "2.0"
  # spec.tvos.deployment_target = "9.0"
  # spec.visionos.deployment_target = "1.0"

  spec.source_files = 'Sources/DotLottie/**/*.{swift,h,m}'

  # Add the xcframework as an internal framework
  spec.vendored_frameworks = 'Sources/DotLottieCore/DotLottiePlayer.xcframework'

  # If you need to specify the header files (if any) from the xcframework, do it here
  spec.public_header_files = 'Sources/DotLottieCore/DotLottiePlayer.xcframework/Headers/*.h'

  spec.requires_arc = true

  spec.test_spec 'DotLottieTests' do |test_spec|
    test_spec.source_files = 'Tests/DotLottieTests/**/*.{swift,h,m}'
    test_spec.dependency 'Quick' # Example test dependency
    test_spec.dependency 'Nimble' # Example test dependency
  end

end
