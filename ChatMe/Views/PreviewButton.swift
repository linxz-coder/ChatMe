//
//  PreviewButton.swift
//  ChatMe
//
//  Created by 林晓中 on 2025/4/17.
//

import SwiftUI

struct PreviewButton: View {
    @ObservedObject var viewModel: ArtifactViewModel
    
    var body: some View {
        Button {
            viewModel.togglePreview()
        } label: {
            HStack(spacing: 1) {
                Image(systemName: viewModel.isPreviewEnabled ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                
                if(viewModel.isPreviewEnabled){
                    LocalizedText(key: "pause")
                        .font(.system(size: 12))
                } else {
                    LocalizedText(key: "play")
                        .font(.system(size: 12))
                }
            }
            .padding(6)
            .background(Color(light: .white.opacity(0.9), dark: Color(red: 0x18/255, green: 0x18/255, blue: 0x18/255)))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(light: Color.gray.opacity(0.2), dark: Color.gray.opacity(0.4)), lineWidth: 1)
            )
            .shadow(color: Color(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.05)), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let artifactViewModel = ArtifactViewModel()
    PreviewButton(viewModel: artifactViewModel)
        .frame(width: 300, height: 300)
        .environmentObject(LocalizationManager.shared)
}
