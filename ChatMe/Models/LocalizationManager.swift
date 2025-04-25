import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    // Current language, use Published to ensure that observers are notified of changes
    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "app_language")
            // Force send update notifications
            self.objectWillChange.send()
        }
    }
    
    private init() {
        // Load the saved language setting from UserDefaults, default to Chinese
        self.language = UserDefaults.standard.string(forKey: "app_language") ?? "zh"
        //        print("Initializing language: \(language)")
    }
    
    func setLanguage(_ languageCode: String) {
        //        print("Setting Language: \(languageCode)")
        self.language = languageCode
    }
    
    func localizedString(_ key: String) -> String {
        // Select the correct language resource pack path based on the current language
        let lprojName = language
        
        guard let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            //            print("Cannot find the languge bundle: \(lprojName)")
            return key
        }
        
        // 使Retrieve translations from the specified package using NSLocalizedString
        let localizedString = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, comment: "")
        
        // Debug information
        //        print("Translation: \(key) -> \(localizedString) [Use \(lprojName)]")
        
        return localizedString
    }
}

// Simple text view component that automatically uses LocalizationManager
struct LocalizedText: View {
    @EnvironmentObject var localization: LocalizationManager
    let key: String
    
    var body: some View {
        Text(localization.localizedString(key))
            .id("\(key)_\(localization.language)") // Ensure that the view is updated when the language changes.
    }
}
