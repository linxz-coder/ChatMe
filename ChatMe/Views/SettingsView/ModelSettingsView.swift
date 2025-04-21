

import SwiftUI

struct ModelSettingsView: View {
    
    @State var selection: Model?
    @EnvironmentObject var settings: ModelSettingsData
    @State private var showAlert = false
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: String? = nil
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                //MARK: - 左侧菜单
                //                List(settings.savedModels, selection: $selection) {
                //                    Text($0.providerName).tag($0)
                //                }
                List(getProviders(), id: \.self, selection: $selectedProvider) { provider in
                    Text(provider).tag(provider)
                }
                .frame(width: geometry.size.width * 0.25) // 1/4 的宽度
                .listStyle(.sidebar)
                //                .onChange(of: selection) {
                //                    settings.selectedModel = selection
                .onChange(of: selectedProvider) { newProvider in
                    // 当选择新提供商时，选择该提供商的第一个模型
                    if let provider = selectedProvider,
                       let firstModel = settings.savedModels.first(where: { $0.providerName == provider }) {
                        selection = firstModel
                        settings.selectedModel = firstModel
                    }
                }
                
                //MARK: - 右侧内容
                if let _ = selection {
                    
                    Form{
                        
                        // 如果当前提供商有多个模型，显示模型选择器
                        if let provider = selectedProvider, hasMultipleModels(for: provider) {
                            VStack(alignment: .leading) {
                                Text("选择模型")
                                    .padding(.bottom, 4)
                                    .padding(.bottom, 4)
                                
                                Picker("", selection: $selection) {
                                    ForEach(getModels(for: provider), id: \.id) { model in
                                        //                                        Text(model.name.isEmpty ? "未选择模型" : model.name).tag(model as Model?)
                                        if !model.name.isEmpty {
                                            Text(model.name).tag(model as Model?)
                                        }
                                    }
                                }
                                .onChange(of: selection) {
                                    if let model = selection {
                                        settings.selectedModel = model
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding()
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Model")
                                .padding(.bottom, 4)
                            
                            TextField("", text: $settings.modelName, prompt: Text("qwen-plus"))
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                        
                        VStack(alignment: .leading) {
                            Text("API Key")
                                .padding(.bottom, 4)
                            
                            SecureField("", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                        
                        VStack(alignment: .leading) {
                            Text("API Base URL")
                                .padding(.bottom, 4)
                            
                            TextField("", text: $settings.baseURL, prompt: Text("https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"))
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                        
                        Spacer()
                        
                        HStack {
                            Button("确认") {
                                     // 强制更新选中的模型以确保所有更改都被应用
                                     if let model = selection {
                                         var updatedModel = model
                                         updatedModel.name = settings.modelName
                                         updatedModel.apiKey = settings.apiKey
                                         updatedModel.baseUrl = settings.baseURL
                                
                                         // 找到并更新模型
                                         if let index = settings.savedModels.firstIndex(where: { $0.id == model.id }) {
                                             settings.savedModels[index] = updatedModel
                                             // 重新设置选中的模型以触发didSet
                                             settings.selectedModel = updatedModel
                                         }
                                     }
                                showAlert = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("返回"){
                                dismiss()
                            }
                        }
                        .padding()
                        
                        .frame(maxWidth: .infinity, alignment: .trailing) // 添加这一行来右对齐
                        
                    }
                    .frame(width: geometry.size.width * 0.75) // 3/4 的宽度
                    .alert("已保存至系统", isPresented: $showAlert) {
                        Button("确定", role: .cancel) { dismiss() }
                    } message: {
                        Text("设置已成功保存")
                    }
                    
                }
            }
            .onAppear {
                // 初始化选择当前模型的提供商
                if let model = settings.selectedModel {
                    selectedProvider = model.providerName
                    selection = model
                } else if let firstProvider = getProviders().first {
                    selectedProvider = firstProvider
                    if let firstModel = getModels(for: firstProvider).first {
                        selection = firstModel
                        settings.selectedModel = firstModel
                    }
                }
            }
        }
    }
    
    // 获取所有提供商列表
    private func getProviders() -> [String] {
        let providers = Array(Set(settings.savedModels.map { $0.providerName })).sorted()
        return providers
    }
    
    // 获取特定提供商的所有模型
    private func getModels(for provider: String) -> [Model] {
        return settings.savedModels
            .filter { $0.providerName == provider }
            .sorted {
                if $0.name.isEmpty { return true }
                if $1.name.isEmpty { return false }
                return $0.name < $1.name
            }
    }
    
    // 判断提供商是否有多个模型
    private func hasMultipleModels(for provider: String) -> Bool {
        let models = settings.savedModels.filter { $0.providerName == provider }
        return models.count > 1
    }
}

#Preview {
    let modelSettings = ModelSettingsData()
    
    ModelSettingsView()
        .environmentObject(modelSettings)
}
