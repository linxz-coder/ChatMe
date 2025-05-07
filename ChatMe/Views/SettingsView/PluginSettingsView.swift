//
//  PluginSettingsView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/28.
//

import SwiftUI

struct PluginSettingsView: View {
    
//    @State var languageSelection = 0
    @State private var tavilyApiKey: String = UserDefaults.standard.string(forKey: "tavilyApiKey") ?? ""
    @State private var showTavilyApiKey: Bool = false
    @State private var savedMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Section(header: LocalizedText(key: "searchPlugin")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tavily")
                        .font(.headline)
                    
                    LocalizedText(key: "provideTavilyKey")
//                    Text("提供 Tavily API 密钥以启用网络搜索功能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if showTavilyApiKey {
                            TextField("Tavily API Key", text: $tavilyApiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Tavily API Key", text: $tavilyApiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disableAutocorrection(true)
                        }
                        
                        Button(action: {
                            showTavilyApiKey.toggle()
                        }) {
                            Image(systemName: showTavilyApiKey ? "eye.slash" : "eye")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button("Save API Key") {
                        // 保存到 UserDefaults
                        UserDefaults.standard.set(tavilyApiKey, forKey: "tavilyApiKey")
                        savedMessage = "API Key Saved"
                        
                        // 2秒后清除保存消息
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            savedMessage = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                    
                    if !savedMessage.isEmpty {
                        Text(savedMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.top, 4)
                    }
                    
                    Text("Get Tavily API Key: https://tavily.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
        }.frame(maxWidth:400)
    }
}
#Preview {
    PluginSettingsView()
        .environmentObject(LocalizationManager.shared)
}
