source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.3'
use_frameworks!

def testing_pods
    pod 'Quick'
    pod 'Nimble'
end

target 'SwoopParkingApp' do
	use_frameworks!
    pod 'SwiftyJSON'
    pod 'Alamofire', '~> 3.9'

    pod "DNTimeAndDay"
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


