#
# CocoaPods fallback for apps that have not enabled Swift Package Manager yet.
# Swift Package Manager (ios/wallet_verifier_api/Package.swift) is the primary
# integration; both build the same sources.
#
Pod::Spec.new do |s|
  s.name             = 'wallet_verifier_api'
  s.version          = '0.1.0'
  s.summary          = 'Verifier API Plugin for iOS Digital ID Verification'
  s.description      = <<-DESC
Flutter wrapper around Apple's Verifier API (ProximityReader) for checking IDs in Apple Wallet.
                       DESC
  s.homepage         = 'https://github.com/kiwis08/wallet_verifier_api'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Santiago Quihui' => 'santiagoquihui@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'wallet_verifier_api/Sources/wallet_verifier_api/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.weak_frameworks = 'ProximityReader'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = { 'wallet_verifier_api_privacy' => ['wallet_verifier_api/Sources/wallet_verifier_api/PrivacyInfo.xcprivacy'] }
end
