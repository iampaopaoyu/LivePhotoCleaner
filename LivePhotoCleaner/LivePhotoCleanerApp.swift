//
//  LivePhotosCleanUpApp.swift
//  LivePhotosCleanUp
//
//  Created by Denise Fritsch on 29.09.20.
//

import SwiftUI
import Firebase

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct LivePhotoCleanerApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            PhotoOverview()
                .environmentObject(SettingsModel())
        }
    }
}
