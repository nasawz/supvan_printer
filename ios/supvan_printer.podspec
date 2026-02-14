#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint supvan_printer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'supvan_printer'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Supvan thermal printers (T50/T50Plus/T50Pro).'
  s.description      = <<-DESC
A Flutter plugin that wraps the Supvan SFPrintSDK for Bluetooth thermal printing.
Supports device scanning, connection, status query, and printing (text, barcode, QR, image).
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  # Vendor the SFPrintSDK xcframework
  s.vendored_frameworks = 'SFPrintSDK.xcframework'

  # CoreBluetooth is required by SFPrintSDK
  s.frameworks = 'CoreBluetooth'

  # Flutter.framework does not contain a i386 slice.
  # -ObjC is required because SFPrintSDK is a static library that uses
  # ObjC categories; without it the linker strips category methods and
  # causes "unrecognized selector" crashes at runtime.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC',
  }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
  s.static_framework = true
  s.swift_version = '5.0'
end
