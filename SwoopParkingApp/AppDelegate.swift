//
//  AppDelegate.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 5/4/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import UIKit
import GoogleMaps
import AWSCore
import DNTimeAndDay

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var restored = false
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        if !restored {
            setupForAppLaunch()
        }
        // Override point for customization after application launch.
        return true
    }
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        setupForAppLaunch()
        restored = true
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    fileprivate func setupForAppLaunch() {
        setupRootViewController(withDAO: SPDataAccessObject())
        GMSServices.provideAPIKey(kSPGoogleMapsKey)
        setupAWS()
    }
    //MARK: - Setup Methods
    fileprivate func setupAWS() {
        let credentialProvider = AWSCognitoCredentialsProvider(regionType:.usEast1, identityPoolId: "us-east-1:14495a5f-65b5-4859-b8f5-4de05fbce775")
        let configuration = AWSServiceConfiguration(region: .usEast1, credentialsProvider:credentialProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    
    fileprivate func setupRootViewController(withDAO dao: SPDataAccessObject) {
        guard let navController = window?.rootViewController as? UINavigationController,
            let mainController = navController.topViewController as? SPMainViewController else { return }
        setupBarButtonFont()
        let sqliteReader = SPSQLiteReader(delegate: dao)
        dao.sqlReader = sqliteReader
        dao.delegate = mainController
        mainController.inject(dao: dao, delegate: dao)
    }
    
    
    fileprivate func setupBarButtonFont() {
        guard let christopherhandFont = UIFont.init(name: "Christopherhand", size: 25) else {
            print("Christopherhand font not available")
            return
        }
        UIBarButtonItem.appearance().setTitleTextAttributes([NSFontAttributeName: christopherhandFont], for: .normal)
    }
}

