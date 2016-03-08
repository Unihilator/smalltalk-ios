platform :ios, '8.0'
xcodeproj 'smalltalk.xcodeproj'
use_frameworks!

source 'https://github.com/CocoaPods/Specs.git'

target 'smalltalk' do
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'Digits'
    pod 'TwitterCore'
    pod 'JSQMessagesViewController' 
    pod 'XMPPFramework'
    #pod 'XMPPFramework', :podspec => 'https://raw.githubusercontent.com/andrey-justo-movile/XMPPFramework/3.7.2/XMPPFramework.podspec.json'
    pod 'ReactiveCocoa', '4.0.0-alpha-3'
    pod 'Reachability'
    pod 'ChameleonFramework/Swift'
    pod 'SnapKit'
    pod 'TSMessages', :git => 'https://github.com/KrauseFx/TSMessages.git'
    pod 'OpenUDID'
    pod 'SwiftyJSON'
    pod 'SDWebImage'
    pod 'DeepLinkKit'
    pod 'NYTPhotoViewer'
    pod 'PhoneNumberKit'
    pod 'Toucan'
    pod "youtube-ios-player-helper", "0.1.4"
    pod "Watchdog"
    pod 'SwiftDate'
end

# Strip alpha/beta notations from build numbers
post_install do |installer|
  plist_buddy = "/usr/libexec/PlistBuddy"

  installer.pods_project.targets.each do |target|
    plist = "Pods/Target Support Files/#{target}/Info.plist"
    version = `#{plist_buddy} -c "Print CFBundleShortVersionString" "#{plist}"`.strip

    stripped_version = /^([\d\.]*)/.match(version).captures[0]

    version_parts = stripped_version.split('.').map { |s| s.to_i }

    # ignore properly formatted versions
    unless version_parts.slice(0..2).join('.') == version

      major, minor, patch = version_parts

      minor ||= 0
      patch = 999

      fixed_version = "#{major}.#{minor}.#{patch}"

      puts "Changing version of #{target} from #{version} to #{fixed_version} to make it pass iTC verification."

      `#{plist_buddy} -c "Set CFBundleShortVersionString #{fixed_version}" "#{plist}"`
    end
  end
end
