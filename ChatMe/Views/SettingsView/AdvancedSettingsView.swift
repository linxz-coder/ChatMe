//
//  AdvancedSettingsView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/28.
//

import SwiftUI

struct AdvancedSettingsView: View {
    
    @EnvironmentObject var localization: LocalizationManager
    @State var languageSelection = 0
    @EnvironmentObject private var modelSettings: ModelSettingsData
    
    var body: some View {
        Form {
            Section {
                TextField(localization.localizedString("proxyUrl"), text: $modelSettings.proxyURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                LocalizedText(key: "proxyNote")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }.frame(maxWidth:400)
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(ModelSettingsData.shared)
        .environmentObject(LocalizationManager.shared)
}
