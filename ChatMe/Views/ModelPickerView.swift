//
//  ModelPickerView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/3.
//

import SwiftUI

struct ModelPickerView: View {
    @EnvironmentObject var settings: ModelSettingsData
    @Binding var isPresented: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // Grouped models by provider
                ForEach(providerGroups(), id: \.name) { provider in
                    VStack(alignment: .leading) {
                        // Providers
                        HStack {
                            modelIcon(for: provider.name)
                            Text(provider.name)
                                .font(.headline)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal)
                        
                        // Models
                        ForEach(provider.models) { model in
                            ModelRow(model: model, isSelected: settings.selectedModel?.id == model.id, isThinkingEnabled: model.isThinkingEnabled)
                                .onTapGesture {
                                    settings.selectedModel = model
                                    isPresented = false
                                }
                            
                            if model.providerName == "Anthropic" {
                                HStack {
                                    LocalizedText(key: "thinkingMode")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: {
                                            // Find the current model and return its thinking mode status
                                            let index = settings.savedModels.firstIndex(where: { $0.id == model.id })
                                            return index != nil ? settings.savedModels[index!].isThinkingEnabled : false
                                        },
                                        set: { newValue in
                                            // Update the thinking mode status of the model
                                            if let index = settings.savedModels.firstIndex(where: { $0.id == model.id }) {
                                                var updatedModel = settings.savedModels[index]
                                                updatedModel.isThinkingEnabled = newValue
                                                settings.savedModels[index] = updatedModel
                                                
                                                // If the currently selected one is this model, also update selectedModel
                                                if settings.selectedModel?.id == model.id {
                                                    settings.selectedModel = updatedModel
                                                }
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .frame(width: 50)
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    
                    Divider()
                }
            }
            .frame(width: 300)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.windowBackgroundColor)
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
        }
    }
    
    // Provider struct
    struct Provider: Identifiable {
        let id = UUID()
        let name: String
        let models: [Model]
    }
    
    
    // Retrieve a list of models grouped by provider
    private func providerGroups() -> [Provider] {
        let groupedModels = Dictionary(grouping: settings.savedModels) { $0.providerName }
        
        return groupedModels.map { providerName, models in
            Provider(
                name: providerName,
                models: models.filter { !$0.name.isEmpty }.sorted {
                    // Sort the models under each provider
                    if $0.name.isEmpty && $1.name.isEmpty {
                        return false // when provider name is model name
                    } else if $0.name.isEmpty {
                        return true // Empty name of providers
                    } else if $1.name.isEmpty {
                        return false // Empty name of models
                    } else {
                        return $0.name < $1.name // models sorted by alphabet
                    }
                }
            )
        }.sorted { $0.name < $1.name } // providerNames sorted by alphabet
    }
    
    // Return different icons for different providers.
    private func modelIcon(for provider: String) -> some View {
        let iconName: String
        
        switch provider {
        case "Anthropic":
            iconName = "claude-color"
        case "OpenAI":
            iconName = "openai-color"
        case "DeepSeek":
            iconName = "deepseek-color"
        case "通义千问":
            iconName = "alibaba-color"
        case "DALL-E-3":
            iconName = "dalle-color"
        case "Google":
            iconName = "gemini-color"
        case "XAI":
            iconName = "grok-color"
        case "智谱清言":
            iconName = "chatglm-color"
        case "月之暗面":
            iconName = "kimi-color"
        case "腾讯混元":
            iconName = "tencentcloud-color"
        default:
            iconName = "openai-color"
        }
        
        return Image(iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
    }
}

// Single model row view
struct ModelRow: View {
    let model: Model
    let isSelected: Bool
    let isThinkingEnabled: Bool
    
    var body: some View {
        HStack {
            
            VStack(alignment: .leading) {
                if !model.name.isEmpty {
                    Text(model.name)
                }
                
                // If it is an Anthropic model and the thinking mode is enabled, display the indicator.
                if model.providerName == "Anthropic" && isThinkingEnabled {
                    LocalizedText(key: "thinkingModeIsON")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // If it is an image model, display the indicator.
                if model.modelType == .image {
                    LocalizedText(key: "imageModel")
                        .font(.caption)
                        .foregroundColor(.teal)
                }
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

#Preview {
    ModelPickerView(isPresented: .constant(true))
        .environmentObject(ModelSettingsData())
        .environmentObject(LocalizationManager.shared)
}
