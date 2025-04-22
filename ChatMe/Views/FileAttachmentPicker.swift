//
//  FileAttachmentPicker.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/17.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileAttachmentPicker: View {
    @ObservedObject var fileManager = FileUploadManager.shared
    @State private var showFilePicker = false
    
    var body: some View {
        VStack {
            // Choose files
            Button {
                showFilePicker = true
            } label: {
                Label{
                    LocalizedText(key: "chooseFiles").font(.subheadline)
                } icon: {
                    Image(systemName: "doc.badge.plus")
                }
                
            }
            .buttonStyle(.borderedProminent)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: SupportedFileType.allCases.compactMap { type in
                    UTType(filenameExtension: type.rawValue)
                },
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        // Obtain secure access privileges
                        if url.startAccessingSecurityScopedResource() {
                            fileManager.addFile(path: url)
                            url.stopAccessingSecurityScopedResource()
                        } else {
                            fileManager.errorMessage = "Unable to access file: \(url.lastPathComponent)"
                        }
                    }
                case .failure(let error):
                    fileManager.errorMessage = "Failed to select file: \(error.localizedDescription)"
                }
            }
            
            // Display error message
            if let errorMessage = fileManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
            
            // Display selected file list
            if !fileManager.uploadedFiles.isEmpty {
                UploadedFilesList()
            }
        }
    }
}

// Uploaded file list view
struct UploadedFilesList: View {
    @ObservedObject var fileManager = FileUploadManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LocalizedText(key: "selectedFiles")
                    .font(.headline)
                
                Spacer()
                
                // Clear Button
                Button {
                    fileManager.removeAllFiles()
                } label: {
                    LocalizedText(key: "clear")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            // List of Files
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(fileManager.uploadedFiles.indices, id: \.self) { index in
                        let file = fileManager.uploadedFiles[index]
                        FileItemView(file: file, index: index)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        }
        .padding(.vertical, 8)
        .background(Color(light: Color(red: 0.95, green: 0.95, blue: 0.95),
                          dark: Color(red: 0.25, green: 0.25, blue: 0.27)))
        .cornerRadius(8)
    }
}

// Single file item view
struct FileItemView: View {
    let file: UploadedFile
    let index: Int
    @ObservedObject var fileManager = FileUploadManager.shared
    
    // Obtain the file size in a readable format
    private var formattedSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: file.size)
    }
    
    // Retrieve file icon
    private var fileIcon: String {
        switch file.type {
        case .pdf:
            return "doc.fill"
        case .docx, .doc:
            return "doc.text.fill"
        case .xls, .xlsx:
            return "tablecells.fill"
        case .ppt, .pptx:
            return "chart.bar.doc.horizontal.fill"
        case .png, .jpg, .jpeg, .bmp, .gif:
            return "photo.fill"
        case .csv:
            return "list.bullet.rectangle.fill"
        case .py:
            return "chevron.left.forwardslash.chevron.right"
        case .txt, .md:
            return "doc.plaintext.fill"
        }
    }
    
    // According to the file type to obtain icon color
    private var iconColor: Color {
        switch file.type {
        case .pdf:
            return .red
        case .docx, .doc:
            return .blue
        case .xls, .xlsx:
            return .green
        case .ppt, .pptx:
            return .orange
        case .png, .jpg, .jpeg, .bmp, .gif:
            return .purple
        case .csv:
            return .gray
        case .py:
            return .yellow
        case .txt, .md:
            return .secondary
        }
    }
    
    var body: some View {
        HStack {
            // File Icon
            Image(systemName: fileIcon)
                .foregroundColor(iconColor)
            
            // File name and size
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack {
                    Text(formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // File status
                    if file.isUploading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 12, height: 12)
                    } else if file.fileId != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else if let errorMessage = file.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Delete button
            Button {
                fileManager.removeFile(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(light: .white, dark: Color(red: 0.3, green: 0.3, blue: 0.32)))
        .foregroundColor(Color(light: .primary, dark: .white))
        .cornerRadius(4)
    }
}

#Preview {
    FileAttachmentPicker()
        .environmentObject(FileUploadManager.shared)
        .environmentObject(LocalizationManager.shared)
        .frame(width: 300, height: 300)
}

#Preview {
    // Create a sample file for preview
    let sampleFile = UploadedFile(
        name: "sample_document.pdf",
        path: URL(string: "file:///sample/path/document.pdf")!,
        size: 1024 * 1024 * 2, // 2MB
        type: .pdf,
        fileId: "sample_id_123",
        isUploading: false,
        
        errorMessage: nil
    )
    
    
    FileItemView(file: sampleFile, index: 0).environmentObject(LocalizationManager.shared)
        .frame(width: 300, height: 300)
}

#Preview{
    UploadedFilesList()
        .environmentObject(FileUploadManager.shared)
        .environmentObject(LocalizationManager.shared)
        .frame(width: 300, height: 300)
}
