//
//  AppDelegate.swift
//  Revolut
//
//  Created by Kacper Kaliński on 19/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private static let appWindow: UIWindow = .init(frame: UIScreen.main.bounds)

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.appWindow.rootViewController = ViewController()
        AppDelegate.appWindow.makeKeyAndVisible()
        return true
    }
}
