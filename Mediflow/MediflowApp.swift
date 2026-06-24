//
//  MediflowApp.swift
//  Mediflow
//
//  Created by vishruth on 30/5/2026.
//

import SwiftUI
import CoreData
import UserNotifications

@main
struct MediflowApp: App {
    let persistence = PersistenceController.shared
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    init() {
        // Only request permission if the user has notifications turned on
        let enabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        }
    }
}
