//
//  PromptSettingsView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/28.
//

import SwiftUI

struct PromptSettingsView: View {
    
    @State var languageSelection = 0
    
    var body: some View {
        Form {
            LocalizedText(key: "comingSoon").frame(maxWidth:400)

        }
    }
}

#Preview {
    PromptSettingsView()
        .environmentObject(LocalizationManager.shared)
}
