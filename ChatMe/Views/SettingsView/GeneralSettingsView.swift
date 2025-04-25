//
//  GenenralSettingsView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/28.
//

import SwiftUI

struct GeneralSettingsView: View {
    
    @EnvironmentObject var localization: LocalizationManager
    @State private var languageSelection: Int = 0
    @State private var forceRefresh: UUID = UUID() // Force refresh the view
    
    var body: some View {
        
        Form {
            
            Picker(selection: $languageSelection) {
                Text("中文").tag(0)
                Text("English").tag(1)
            } label: {
                Text(localization.localizedString("interface_language"))
            }
            .onChange(of: languageSelection) { _, newValue in
                // Update System Language setting
                let languageCode = newValue == 0 ? "zh" : "en"
                localization.setLanguage(languageCode)
            }
            .onAppear {
                // Ensure that the initial value matches the current language.
                languageSelection = localization.language == "en" ? 1 : 0
            }
        }
        .frame(maxWidth:400)
        .id(forceRefresh) // Force view refresh using UUID
        .onAppear {
            // Set the correct language selector state when the view appears
            languageSelection = localization.language == "en" ? 1 : 0
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))) { _ in
            // Receive language change notification
            forceRefresh = UUID() // Force refresh
        }
    }
}

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        return Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

#Preview {
    GeneralSettingsView()
        .environmentObject(LocalizationManager.shared)
        .frame(width: 600, height: 300)
}
