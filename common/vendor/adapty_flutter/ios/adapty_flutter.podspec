# BLOKADA VENDOR STUB — not part of the upstream package.
#
# adapty_flutter 4.x dropped CocoaPods (SwiftPM only). The app consumes the
# real plugin as a Swift package via `flutter build swift-package`. However,
# Flutter modules still force a CocoaPods pass over every plugin
# (flutter/flutter#184590): the generated FlutterPluginRegistrant pod hard-
# depends on `adapty_flutter`, so `pod install` fails when the plugin has no
# podspec at all. This stub exists only to let that vestigial pods pass
# resolve and compile; its build product is discarded by
# `flutter build swift-package` (module plugins vended as Swift packages are
# skipped when collecting CocoaPods frameworks). Nothing from here ships.
#
# Remove together with vendor/adapty_flutter once flutter/flutter#184590 is
# fixed in the pinned Flutter SDK.
Pod::Spec.new do |s|
  s.name             = 'adapty_flutter'
  s.version          = '4.0.4'
  s.summary          = 'CocoaPods resolution stub for the SwiftPM-only Adapty Flutter plugin.'
  s.description      = 'Satisfies the generated FlutterPluginRegistrant pod dependency; never shipped.'
  s.homepage         = 'https://adapty.io'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Blokada' => 'hello@blokada.org' }
  s.source           = { :path => '.' }
  s.source_files     = 'stub/*.{h,m}'
  s.public_header_files = 'stub/*.h'
  s.dependency 'Flutter'
  # The real iOS 15 floor is enforced by the actual Swift package in the host
  # app; the stub matches the module project so the pods pass doesn't balk.
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
