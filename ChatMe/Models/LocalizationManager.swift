// LocalizationManager.swift - 完全重写以修复问题
import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    // 当前语言，使用Published确保更改时通知观察者
    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "app_language")
            // 强制发送更新通知
            self.objectWillChange.send()
        }
    }
    
    private init() {
        // 从UserDefaults加载保存的语言设置，默认为中文
        self.language = UserDefaults.standard.string(forKey: "app_language") ?? "zh"
//        print("初始化语言: \(language)")
    }
    
    func setLanguage(_ languageCode: String) {
//        print("设置语言: \(languageCode)")
        self.language = languageCode
    }
    
    func localizedString(_ key: String) -> String {
        // 根据当前语言选择正确的语言资源包路径
        let lprojName = language
        
        guard let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
//            print("无法找到语言包: \(lprojName)")
            return key
        }
        
        // 使用NSLocalizedString从指定的包中获取翻译
        let localizedString = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, comment: "")
        
        // 输出调试信息
//        print("翻译: \(key) -> \(localizedString) [使用\(lprojName)]")
        
        return localizedString
    }
}

// 简便的文本视图组件，自动使用LocalizationManager
struct LocalizedText: View {
    @EnvironmentObject var localization: LocalizationManager
    let key: String
    
    var body: some View {
        Text(localization.localizedString(key))
            .id("\(key)_\(localization.language)") // 确保语言变化时视图更新
    }
}
