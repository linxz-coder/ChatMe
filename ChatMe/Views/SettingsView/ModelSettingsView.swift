

import SwiftUI

struct ModelSettingsView: View {
    
    @EnvironmentObject var localization: LocalizationManager
    @State var selection: Model?
    @EnvironmentObject var settings: ModelSettingsData
    @State private var showAlert = false
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: String? = nil
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                //MARK: - SideBar
                List(getProviders(), id: \.self, selection: $selectedProvider) { provider in
                    Text(provider).tag(provider)
                }
                .frame(width: geometry.size.width * 0.25) // 1/4 width
                .listStyle(.sidebar)
                .onChange(of: selectedProvider) {_, newProvider in
                    // When choosing a new provider, select the first model of the provider.
                    if let provider = selectedProvider,
                       let firstModel = settings.savedModels.first(where: { $0.providerName == provider }) {
                        selection = firstModel
                        settings.selectedModel = firstModel
                    }
                }
                
                //MARK: - Content
                if let _ = selection {
                    Form{
                        // If the current provider has multiple models, display the model selector.
                        if let provider = selectedProvider, hasMultipleModels(for: provider) {
                            VStack(alignment: .leading) {
                                Text("Select Model")
                                    .padding(.bottom, 4)
                                    .padding(.bottom, 4)
                                
                                Picker("", selection: $selection) {
                                    ForEach(getModels(for: provider), id: \.id) { model in
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
                            Button {
                                // Force update the selected model to ensure that all changes are applied
                                if let model = selection {
                                    var updatedModel = model
                                    updatedModel.name = settings.modelName
                                    updatedModel.apiKey = settings.apiKey
                                    updatedModel.baseUrl = settings.baseURL
                                    
                                    // Find and update the model
                                    if let index = settings.savedModels.firstIndex(where: { $0.id == model.id }) {
                                        settings.savedModels[index] = updatedModel
                                        // Reset the selected model to trigger didSet
                                        settings.selectedModel = updatedModel
                                    }
                                }
                                showAlert = true
                            } label: {
                                LocalizedText(key: "confirm")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            
                            Button{
                                dismiss()
                            }label: {
                                LocalizedText(key: "cancel")
                            }
                        }
                        .padding()
                        
                        .frame(maxWidth: .infinity, alignment: .trailing) // Add this line to align to the right
                        
                    }
                    .frame(width: geometry.size.width * 0.75) // 3/4 width
                    .alert(localization.localizedString("saveToSystem"), isPresented: $showAlert) {
                        Button {
                            dismiss()
                        } label: {
                            LocalizedText(key: "confirm")
                        }
                    } message: {
                        LocalizedText(key: "saveModel")
                    }
                    
                }
            }
            .onAppear {
                // Initialize the selection of the current model provider
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
    
    // Retrieve the list of all providers
    private func getProviders() -> [String] {
        let providers = Array(Set(settings.savedModels.map { $0.providerName })).sorted()
        return providers
    }
    
    // Retrieve all models from a specific provider
    private func getModels(for provider: String) -> [Model] {
        return settings.savedModels
            .filter { $0.providerName == provider }
            .sorted {
                if $0.name.isEmpty { return true }
                if $1.name.isEmpty { return false }
                return $0.name < $1.name
            }
    }
    
    // Check if the provider has multiple models
    private func hasMultipleModels(for provider: String) -> Bool {
        let models = settings.savedModels.filter { $0.providerName == provider }
        return models.count > 1
    }
}

#Preview {
    let modelSettings = ModelSettingsData()
    
    ModelSettingsView()
        .environmentObject(modelSettings)
        .environmentObject(LocalizationManager.shared)
        .frame(height: 600)
}
