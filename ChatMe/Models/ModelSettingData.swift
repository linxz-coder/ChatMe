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
            
            // 保存旧模型的编辑内容
            if let oldModel = oldValue, oldModel.id != selectedModel?.id {
                var updatedOldModel = oldModel
                updatedOldModel.name = self.modelName
                updatedOldModel.apiKey = self.apiKey
                updatedOldModel.baseUrl = self.baseURL
                // 找到旧模型在数组中的索引，直接更新
                if let index = savedModels.firstIndex(where: { $0.id == oldModel.id }) {
                    savedModels[index] = updatedOldModel
                    print("保存旧模型到索引 \(index): \(updatedOldModel.providerName)")
                }
            }
            
            if let model = selectedModel {
                // 先从 savedModels 获取最新版本的模型
                if let index = savedModels.firstIndex(where: { $0.id == model.id }) {
                    let latestModel = savedModels[index]
                    self.apiKey = latestModel.apiKey
                    self.baseURL = latestModel.baseUrl
                    self.modelName = latestModel.name
                    print("从 savedModels 加载最新版本: \(latestModel.providerName)")
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
    
    //代理设置
    @Published var proxyURL: String = "" {
        didSet {
            defaults.set(proxyURL, forKey: UserDefaultsKeys.proxyURL)
        }
    }
    
    init() {
        
        initializing = true
        
        // 加载代理URL设置
        if let savedProxyURL = defaults.string(forKey: UserDefaultsKeys.proxyURL) {
            self.proxyURL = savedProxyURL
        } else {
            self.proxyURL = "http://127.0.0.1:1087"  // 默认代理设置
            defaults.set(self.proxyURL, forKey: UserDefaultsKeys.proxyURL)
        }
        
        
        loadSavedModels()
        
        // 临时：清除所有"DeepSeek Chat"和"DeepSeek Reasoner"模型
        //        savedModels.removeAll(where: {
        //            $0.providerName == "DeepSeek" &&
        //            ($0.name == "DeepSeek Chat" || $0.name == "DeepSeek Reasoner")
        //        })
        
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
        // 结构改为[提供商名称, 基础URL, 模型名称数组]
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
        
        // Check if each default model exists, add if not
        //        for (providerName, baseUrl) in defaultModels {
        //            if !savedModels.contains(where: { $0.providerName == providerName }) {
        //                print("Adding missing model: \(providerName)")
        //                           let modelType: ModelType = providerName == "DALL-E-3" ? .image : .chat
        //                           let newModel = Model(providerName: providerName, name: "", baseUrl: baseUrl, apiKey: "", isThinkingEnabled: false, modelType: modelType)
        //                savedModels.append(newModel)
        //                modelsChanged = true
        //            }
        //        }
        
        // 遍历每个提供商及其模型
        for (providerName, baseUrl, modelNames) in defaultModels {
            // 确定模型类型
            let modelType: ModelType = providerName == "DALL-E-3" ? .image : .chat
            
            // 如果模型名数组为空或只包含空字符串，添加一个默认模型
            if modelNames.isEmpty || (modelNames.count == 1 && modelNames[0].isEmpty) {
                if !savedModels.contains(where: { $0.providerName == providerName && $0.name.isEmpty }) {
                    print("Adding default model for provider: \(providerName)")
                    let newModel = Model(providerName: providerName, name: "", baseUrl: baseUrl, apiKey: "", isThinkingEnabled: false, modelType: modelType)
                    savedModels.append(newModel)
                    modelsChanged = true
                }
            } else {
                // 添加所有指定的模型
                for modelName in modelNames {
                    // 检查该模型是否存在
                    if !savedModels.contains(where: { $0.providerName == providerName && $0.name == modelName }) {
                        print("Adding model: \(providerName) - \(modelName)")
                        
                        // 特殊处理Claude Thinking模型
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
    
    // 更新保存的模型列表中的特定模型
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
    
    // 判断当前模型是否需要使用代理
    func shouldUseProxy() -> Bool {
        guard let model = selectedModel else { return false }
        return model.providerName == "Anthropic" || model.providerName == "OpenAI"
    }
    
    // 获取代理配置
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
