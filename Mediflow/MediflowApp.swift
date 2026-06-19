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
    
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notifications permission granted: \(granted)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
