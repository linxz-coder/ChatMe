//
//  SettingsView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/28.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        TabView{
            GeneralSettingsView()
                .tabItem {
                    Label {
                        LocalizedText(key: "general")
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
            
            ModelSettingsView()
                .tabItem {
                    Label {
                        LocalizedText(key: "models")
                    } icon: {
                        Image(systemName: "cpu")
                    }
                }
            
            PromptSettingsView()
                .tabItem {
                    Label {
                        LocalizedText(key: "prompts")
                    } icon: {
                        Image(systemName: "book")
                    }
                }
            
            PluginSettingsView()
                .tabItem {
                    Label {
                        LocalizedText(key: "plugins")
                    } icon: {
                        Image(systemName: "puzzlepiece")
                    }
                }
            
            AdvancedSettingsView()
                .tabItem {
                    Label {
                        LocalizedText(key: "advanced")
                    } icon: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
        }
        .padding()
        .frame(maxWidth:.infinity, maxHeight: .infinity)
    }
}

#Preview {
    
    // Create the required environment objects
    let modelSettings = ModelSettingsData.shared
    
    SettingsView()
        .environmentObject(LocalizationManager.shared)
        .environmentObject(modelSettings)
}
