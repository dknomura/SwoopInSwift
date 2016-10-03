source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.3'
use_frameworks!

def testing_pods
    pod 'Quick'
    pod 'Nimble'
end

target 'SwoopParkingApp' do
	pod "DNTimeAndDay"
	use_frameworks!
	pod 'GoogleMaps'
	pod 'AWSLambda'
	pod 'AWSCognito'	
end

target 'SwoopParkingAppUITests' do
    inherit! :search_paths
    testing_pods 
end

target 'SwoopParkingAppTests' do
    inherit! :search_paths
    testing_pods
end


