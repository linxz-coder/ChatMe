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
    @State private var forceRefresh: UUID = UUID() // 用于强制刷新视图
    
    
    var body: some View {
        
        Form {
            
            Picker(selection: $languageSelection) {
                Text("中文").tag(0)
                Text("English").tag(1)
            } label: {
                Text(localization.localizedString("interface_language"))
            }
            .onChange(of: languageSelection) { newValue in
                // 更新语言设置
                let languageCode = newValue == 0 ? "zh" : "en"
                localization.setLanguage(languageCode)
            }
            .onAppear {
                // 确保初始值与当前语言匹配
                languageSelection = localization.language == "en" ? 1 : 0
            }
        }
        .frame(maxWidth:400)
        .id(forceRefresh) // 使用UUID强制视图重建
        .onAppear {
            // 在视图出现时设置正确的语言选择器状态
            languageSelection = localization.language == "en" ? 1 : 0
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))) { _ in
            // 接收语言变更通知
            forceRefresh = UUID() // 强制刷新
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
    GeneralSettingsView().environmentObject(LocalizationManager.shared)
}
