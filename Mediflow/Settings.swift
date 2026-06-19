//
//  Settings.swift
//  Mediflow
//
//  Created by vishruth on 1/6/2026.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

struct Settings: View {
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: themeRaw) ?? .system },
            set: { newValue in themeRaw = newValue.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("App Theme", selection: themeBinding) {
                        Text("Standard").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notifications") {
                }

                Section("About") {
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    Settings()
}
