//
//  GenenralSettingsView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/28.
//

import SwiftUI

struct AdvancedSettingsView: View {
    
    @State var languageSelection = 0
    @EnvironmentObject private var modelSettings: ModelSettingsData
    
    var body: some View {
        Form {
            Section {
                TextField("代理URL", text: $modelSettings.proxyURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                Text("注意：代理仅用于Anthropic和OpenAI API")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }.frame(maxWidth:400)
    }
}

#Preview {
    AdvancedSettingsView()
}
