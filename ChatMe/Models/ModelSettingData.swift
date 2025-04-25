//
//  ModelSettingData.swift
//  ChatMe
//

import Foundation

let defaults = UserDefaults.standard
var initializing = false

class ModelSettingsData: ObservableObject {
    static let shared = ModelSettingsData()
    
    @Published var apiKey: String = "" {
        didSet {
            defaults.set(apiKey, forKey: UserDefaultsKeys.apiKey)
            
            if var model = selectedModel {
                model.apiKey = apiKey
                updateModelInSavedModels(model)
            }
        }
    }
    
    @Published var baseURL: String = "" {
        didSet {
            defaults.set(baseURL, forKey: UserDefaultsKeys.baseURL)
            
            if var model = selectedModel {
                model.baseUrl = baseURL
                updateModelInSavedModels(model)
            }
        }
    }
    
    @Published var modelName: String = ""{
        didSet {
            defaults.set(modelName, forKey: UserDefaultsKeys.modelName)
            
            if var model = selectedModel {
                model.name = modelName
                updateModelInSavedModels(model)
            }
        }
    }
    
    @Published var selectedModel: Model? {
        didSet {
            
            if initializing { return }
            
            // Save the editing content of the old model
            if let oldModel = oldValue, oldModel.id != selectedModel?.id {
                var updatedOldModel = oldModel
                updatedOldModel.name = self.modelName
                updatedOldModel.apiKey = self.apiKey
                updatedOldModel.baseUrl = self.baseURL
                // Find the index of the old model in the array and update it directly.
                if let index = savedModels.firstIndex(where: { $0.id == oldModel.id }) {
                    savedModels[index] = updatedOldModel
                    print("Save old model to index \(index): \(updatedOldModel.providerName)")
                }
            }
            
            if let model = selectedModel {
                // Get the most updated models from savedModels
                if let index = savedModels.firstIndex(where: { $0.id == model.id }) {
                    let latestModel = savedModels[index]
                    self.apiKey = latestModel.apiKey
                    self.baseURL = latestModel.baseUrl
                    self.modelName = latestModel.name
                    print("Get the most updated models from savedModels: \(latestModel.providerName)")
                } else {
                    self.apiKey = model.apiKey
                    self.baseURL = model.baseUrl
                    self.modelName = model.name
                }
                
                // Save selected model name
                defaults.set(model.providerName, forKey: UserDefaultsKeys.selectedModelName)
                
                if let index = savedModels.firstIndex(where: { $0.id == model.id }) {
                    if savedModels[index].isThinkingEnabled != model.isThinkingEnabled {
                        var updatedModel = savedModels[index]
                        updatedModel.isThinkingEnabled = model.isThinkingEnabled
                        savedModels[index] = updatedModel
                    }
                }
            }
        }
    }
    
    @Published var savedModels: [Model] = [] {
        didSet {
            saveModelsToUserDefaults()
        }
    }
    
    //Proxy settings
    @Published var proxyURL: String = "" {
        didSet {
            defaults.set(proxyURL, forKey: UserDefaultsKeys.proxyURL)
        }
    }
    
    init() {
        
        initializing = true
        
        // Load proxy URL
        if let savedProxyURL = defaults.string(forKey: UserDefaultsKeys.proxyURL) {
            self.proxyURL = savedProxyURL
        } else {
            self.proxyURL = "http://127.0.0.1:1087"  // Default proxy settings
            defaults.set(self.proxyURL, forKey: UserDefaultsKeys.proxyURL)
        }
        
        loadSavedModels()
        
        ensureNewModelsExist()
        
        initializing = false
        
        if let selectedModelName = defaults.string(forKey: UserDefaultsKeys.selectedModelName),
           let selectedModel = savedModels.first(where: { $0.providerName == selectedModelName }) {
            self.selectedModel = selectedModel
        }
    }
    
    func loadSavedModels() {
        
        if let savedData = defaults.data(forKey: UserDefaultsKeys.models),
           let decodedModels = try? JSONDecoder().decode([Model].self, from: savedData) {
            self.savedModels = decodedModels
        } else {
            self.savedModels = [
                Model(providerName: "Anthropic", name:"", baseUrl: "https://api.anthropic.com/v1/messages", apiKey: ""),
                Model(providerName: "OpenAI", name:"", baseUrl: "https://api.openai.com/v1/chat/completions", apiKey: ""),
                Model(providerName: "DeepSeek", name:"", baseUrl: "https://api.deepseek.com/v1/chat/completions", apiKey: ""),
                Model(providerName: "通义千问", name:"", baseUrl: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", apiKey: ""),
                Model(providerName: "腾讯混元", name:"", baseUrl: "https://api.hunyuan.cloud.tencent.com/v1/chat/completions", apiKey: "")]
        }
    }
    
    func ensureNewModelsExist(){
        let defaultModels: [(String, String, [String])] = [
            ("Anthropic", "https://api.anthropic.com/v1/messages", ["claude-3-7-sonnet-20250219"]),
            ("OpenAI", "https://api.openai.com/v1/chat/completions", ["gpt-4o-mini"]),
            ("DeepSeek", "https://api.deepseek.com/v1/chat/completions", ["deepseek-chat"]),
            ("通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", ["qwen-plus", "qwen-turbo", "qwen-max"]),
            ("腾讯混元", "https://api.hunyuan.cloud.tencent.com/v1/chat/completions", ["hunyuan-turbo"]),
            ("月之暗面", "https://api.moonshot.cn/v1/chat/completions", ["moonshot-v1-8k"]),
            ("智谱清言", "https://open.bigmodel.cn/api/paas/v4/chat/completions", ["glm-4-long", "glm-4-air"]),
            ("Google", "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", ["gemini-2.0-flash", "gemini-2.5-pro-preview-03-25", "gemini-1.5-flash"]),
            ("XAI", "https://api.x.ai/v1/chat/completions", ["grok-2-latest"]),
            ("DALL-E-3", "https://api.openai.com/v1/images/generations", ["dall-e-3"])
        ]
        
        
        var modelsChanged = false
        
        // Map providers and their models
        for (providerName, baseUrl, modelNames) in defaultModels {
            // Get model type
            let modelType: ModelType = providerName == "DALL-E-3" ? .image : .chat
            
            // If the model name array is empty or only contains empty strings, add a default model.
            if modelNames.isEmpty || (modelNames.count == 1 && modelNames[0].isEmpty) {
                if !savedModels.contains(where: { $0.providerName == providerName && $0.name.isEmpty }) {
                    print("Adding default model for provider: \(providerName)")
                    let newModel = Model(providerName: providerName, name: "", baseUrl: baseUrl, apiKey: "", isThinkingEnabled: false, modelType: modelType)
                    savedModels.append(newModel)
                    modelsChanged = true
                }
            } else {
                // Add all specified models
                for modelName in modelNames {
                    // Check if the model exists
                    if !savedModels.contains(where: { $0.providerName == providerName && $0.name == modelName }) {
                        print("Adding model: \(providerName) - \(modelName)")
                        
                        // Special treatment of Claude Thinking model
                        let isThinking = modelName.contains("Thinking")
                        
                        let newModel = Model(
                            providerName: providerName,
                            name: modelName,
                            baseUrl: baseUrl,
                            apiKey: "",
                            isThinkingEnabled: isThinking,
                            modelType: modelType
                        )
                        savedModels.append(newModel)
                        modelsChanged = true
                    }
                }
            }
        }
        
        if modelsChanged {
            saveModelsToUserDefaults()
        }
        
    }
    
    // Update the list of saved models to include a specific model
    private func updateModelInSavedModels(_ model: Model) {
        if let index = savedModels.firstIndex(where: { $0.id == model.id }) {
            savedModels[index] = model
        }
    }
    
    private func saveModelsToUserDefaults() {
        if let encodedData = try? JSONEncoder().encode(savedModels) {
            defaults.set(encodedData, forKey: UserDefaultsKeys.models)
        }
    }
    
    // Check whether the current model needs to use proxy
    func shouldUseProxy() -> Bool {
        guard let model = selectedModel else { return false }
        return model.providerName == "Anthropic" || model.providerName == "OpenAI"
    }
    
    // Get proxy configuration
    func getProxyConfiguration() -> URLSessionConfiguration? {
        if !shouldUseProxy() || proxyURL.isEmpty {
            return nil
        }
        
        guard let url = URL(string: proxyURL) else {
            print("Invalid proxy URL")
            return nil
        }
        
        let configuration = URLSessionConfiguration.default
        let host = url.host ?? "127.0.0.1"
        let port = url.port ?? 1087
        
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPProxy: host,
            kCFNetworkProxiesHTTPPort: port,
            kCFNetworkProxiesHTTPSEnable: true,
            kCFNetworkProxiesHTTPSProxy: host,
            kCFNetworkProxiesHTTPSPort: port
        ]
        
        return configuration
    }
}
