//
//  FileUploadManager.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/17.
//

import Foundation
import SwiftUI

// Supported file type enumeration
enum SupportedFileType: String, CaseIterable {
    case pdf = "pdf"
    case docx = "docx"
    case doc = "doc"
    case xls = "xls"
    case xlsx = "xlsx"
    case ppt = "ppt"
    case pptx = "pptx"
    case png = "png"
    case jpg = "jpg"
    case jpeg = "jpeg"
    case csv = "csv"
    case py = "py"
    case txt = "txt"
    case md = "md"
    case bmp = "bmp"
    case gif = "gif"
    
    // Retrieve all supported file types' UTI
    static var allUTIs: [String] {
        var utis: [String] = []
        for type in allCases {
            switch type {
            case .pdf:
                utis.append("com.adobe.pdf")
            case .docx:
                utis.append("org.openxmlformats.wordprocessingml.document")
            case .doc:
                utis.append("com.microsoft.word.doc")
            case .xls:
                utis.append("com.microsoft.excel.xls")
            case .xlsx:
                utis.append("org.openxmlformats.spreadsheetml.sheet")
            case .ppt:
                utis.append("com.microsoft.powerpoint.ppt")
            case .pptx:
                utis.append("org.openxmlformats.presentationml.presentation")
            case .png:
                utis.append("public.png")
            case .jpg, .jpeg:
                utis.append("public.jpeg")
            case .csv:
                utis.append("public.comma-separated-values-text")
            case .py:
                utis.append("public.python-script")
            case .txt:
                utis.append("public.plain-text")
            case .md:
                utis.append("net.daringfireball.markdown")
            case .bmp:
                utis.append("com.microsoft.bmp")
            case .gif:
                utis.append("com.compuserve.gif")
            }
        }
        return utis
    }
    
    // Returns file type based on file UTI
    static func fromUTI(_ uti: String) -> SupportedFileType? {
        switch uti {
        case "com.adobe.pdf":
            return .pdf
        case "org.openxmlformats.wordprocessingml.document":
            return .docx
        case "com.microsoft.word.doc":
            return .doc
        case "com.microsoft.excel.xls":
            return .xls
        case "org.openxmlformats.spreadsheetml.sheet":
            return .xlsx
        case "com.microsoft.powerpoint.ppt":
            return .ppt
        case "org.openxmlformats.presentationml.presentation":
            return .pptx
        case "public.png":
            return .png
        case "public.jpeg":
            return .jpg
        case "public.comma-separated-values-text":
            return .csv
        case "public.python-script":
            return .py
        case "public.plain-text":
            return .txt
        case "net.daringfireball.markdown":
            return .md
        case "com.microsoft.bmp":
            return .bmp
        case "com.compuserve.gif":
            return .gif
        default:
            return nil
        }
    }
    
    // Check if it is Image
    var isImage: Bool {
        switch self {
        case .png, .jpg, .jpeg, .bmp, .gif:
            return true
        default:
            return false
        }
    }
}

// Upload File struct
struct UploadedFile: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    let type: SupportedFileType
    var fileId: String? // the id Chatglm returns
    var isUploading: Bool = false
    var uploadProgress: Double = 0.0
    var errorMessage: String? = nil
    
    static func == (lhs: UploadedFile, rhs: UploadedFile) -> Bool {
        return lhs.id == rhs.id
    }
}

class FileUploadManager: ObservableObject {
    @Published var uploadedFiles: [UploadedFile] = []
    @Published var isUploading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Singleton pattern
    static let shared = FileUploadManager()
    
    private init() {}
    
    // Check if the file size meets the requirements
    private func validateFileSize(size: Int64, fileType: SupportedFileType) -> Bool {
        if fileType.isImage {
            // Image size limit 5MB
            return size <= 5 * 1024 * 1024
        } else {
            // Other files limit 50MB
            return size <= 50 * 1024 * 1024
        }
    }
    
    // Add file to list
    func addFile(path: URL) {
        // Check total file number limit
        if uploadedFiles.count >= 100 {
            errorMessage = "The number of files has reached the limit (100)."
            return
        }
        
        // Get file information
        let fileName = path.lastPathComponent
        let fileExtension = path.pathExtension.lowercased()
        
        // Verify file type
        guard let fileType = SupportedFileType(rawValue: fileExtension) else {
            errorMessage = "Unsupported type: .\(fileExtension)"
            return
        }
        
        // Get file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Verify file size
            if !validateFileSize(size: fileSize, fileType: fileType) {
                if fileType.isImage {
                    errorMessage = "Image size exceeds the limit (5MB)"
                } else {
                    errorMessage = "File size exceeds the limit (50MB)"
                }
                return
            }
            
            // Create a new file object and add it to the list
            let newFile = UploadedFile(
                name: fileName,
                path: path,
                size: fileSize,
                type: fileType
            )
            
            DispatchQueue.main.async {
                self.uploadedFiles.append(newFile)
                self.errorMessage = nil
            }
            
        } catch {
            errorMessage = "Fail to read file: \(error.localizedDescription)"
        }
    }
    
    // Remove File
    func removeFile(at index: Int) {
        guard index < uploadedFiles.count else { return }
        
        DispatchQueue.main.async {
            self.uploadedFiles.remove(at: index)
        }
    }
    
    // Remove all files
    func removeAllFiles() {
        DispatchQueue.main.async {
            self.uploadedFiles.removeAll()
        }
    }
    
    // Upload file to zhipu AI
    func uploadFileToZhipuAI(file: UploadedFile, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Update file status to uploading
        if let index = uploadedFiles.firstIndex(where: { $0.id == file.id }) {
            var updatedFile = uploadedFiles[index]
            updatedFile.isUploading = true
            uploadedFiles[index] = updatedFile
        }
        
        // Set request URL
        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/files") else {
            if let index = uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                var updatedFile = uploadedFiles[index]
                updatedFile.isUploading = false
                updatedFile.errorMessage = "Invalid URL"
                uploadedFiles[index] = updatedFile
            }
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // Make request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set request head of Authorization
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Set Content-Type as multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add purpose
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        data.append("file-extract\r\n".data(using: .utf8)!) // Use "batch"、"retrieval" when needed
        
        // Append file data
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.name)\"\r\n".data(using: .utf8)!)
        
        // Set types of file
        let mimeType: String
        switch file.type {
        case .pdf:
            mimeType = "application/pdf"
        case .docx, .doc:
            mimeType = "application/msword"
        case .xls, .xlsx:
            mimeType = "application/vnd.ms-excel"
        case .ppt, .pptx:
            mimeType = "application/vnd.ms-powerpoint"
        case .png:
            mimeType = "image/png"
        case .jpg, .jpeg:
            mimeType = "image/jpeg"
        case .csv:
            mimeType = "text/csv"
        case .py, .txt, .md:
            mimeType = "text/plain"
        case .bmp:
            mimeType = "image/bmp"
        case .gif:
            mimeType = "image/gif"
        }
        
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        
        // Read File Data
        do {
            let fileData = try Data(contentsOf: file.path)
            data.append(fileData)
            data.append("\r\n".data(using: .utf8)!)
        } catch {
            if let index = uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                var updatedFile = uploadedFiles[index]
                updatedFile.isUploading = false
                updatedFile.errorMessage = "Fail to read file data: \(error.localizedDescription)"
                uploadedFiles[index] = updatedFile
            }
            completion(.failure(error))
            return
        }
        
        // Add end tag
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Make request
        request.httpBody = data
        
        // Print request details for debugging
        print("Upload File: \(file.name)")
        print("URL: \(url.absoluteString)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Body size: \(data.count) bytes")
        
        // Create upload task
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Upload Error: \(error.localizedDescription)")
                if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                    var updatedFile = self.uploadedFiles[index]
                    updatedFile.isUploading = false
                    updatedFile.errorMessage = "Upload Error: \(error.localizedDescription)"
                    DispatchQueue.main.async {
                        self.uploadedFiles[index] = updatedFile
                    }
                }
                completion(.failure(error))
                return
            }
            
            // Print response status and data
            if let httpResponse = response as? HTTPURLResponse {
                print("StatusCode: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                        var updatedFile = self.uploadedFiles[index]
                        updatedFile.isUploading = false
                        updatedFile.errorMessage = "Server returned an error: \(httpResponse.statusCode)"
                        DispatchQueue.main.async {
                            self.uploadedFiles[index] = updatedFile
                        }
                    }
                    
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("Server error details: \(errorString)")
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: ["message": errorString])))
                    } else {
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: nil)))
                    }
                    return
                }
            }
            
            // Parse response data
            guard let data = data else {
                print("No response data")
                if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                    var updatedFile = self.uploadedFiles[index]
                    updatedFile.isUploading = false
                    updatedFile.errorMessage = "No response Data"
                    DispatchQueue.main.async {
                        self.uploadedFiles[index] = updatedFile
                    }
                }
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            // Print the returned data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response Data: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check the JSON structure to see which level the id is on.
                    if let fileId = json["id"] as? String {
                        // if it is in first level
                        print("Upload succeed，ID: \(fileId)")
                        
                        if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                            var updatedFile = self.uploadedFiles[index]
                            updatedFile.isUploading = false
                            updatedFile.fileId = fileId
                            DispatchQueue.main.async {
                                self.uploadedFiles[index] = updatedFile
                            }
                        }
                        
                        completion(.success(fileId))
                    } else if let data = json["data"] as? [String: Any], let fileId = data["id"] as? String {
                        // In the data sub-object
                        print("Upload succeed，ID: \(fileId)")
                        
                        if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                            var updatedFile = self.uploadedFiles[index]
                            updatedFile.isUploading = false
                            updatedFile.fileId = fileId
                            DispatchQueue.main.async {
                                self.uploadedFiles[index] = updatedFile
                            }
                        }
                        
                        completion(.success(fileId))
                    } else {
                        // 找不到ID
                        print("File ID not found in response data")
                        print("Response Data: \(json)")
                        
                        if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                            var updatedFile = self.uploadedFiles[index]
                            updatedFile.isUploading = false
                            updatedFile.errorMessage = "Fail to parse response，cannot find file ID"
                            DispatchQueue.main.async {
                                self.uploadedFiles[index] = updatedFile
                            }
                        }
                        
                        completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": "Cannot find file ID"])))
                    }
                } else {
                    print("Cannot parse JSON response")
                    
                    if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                        var updatedFile = self.uploadedFiles[index]
                        updatedFile.isUploading = false
                        updatedFile.errorMessage = "Fail to parse response"
                        DispatchQueue.main.async {
                            self.uploadedFiles[index] = updatedFile
                        }
                    }
                    
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Fail to parse response"
                    completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": errorMessage])))
                }
            } catch {
                print("Fail to parse JSON: \(error.localizedDescription)")
                
                if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                    var updatedFile = self.uploadedFiles[index]
                    updatedFile.isUploading = false
                    updatedFile.errorMessage = "Fail to parse: \(error.localizedDescription)"
                    DispatchQueue.main.async {
                        self.uploadedFiles[index] = updatedFile
                    }
                }
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // Get file content from Zhipu AI
    func getFileContent(fileId: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Set request URL
        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/files/\(fileId)/content") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // set Authorization header
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Print request to debug
        print("Request to get file content:")
        print("URL: \(url.absoluteString)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Fail to get file content: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // print HTTP Response
            if let httpResponse = response as? HTTPURLResponse {
                print("File content response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("Server error: \(errorString)")
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: ["message": errorString])))
                    } else {
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: nil)))
                    }
                    return
                }
            }
            
            // Parse response data
            guard let data = data else {
                print("No file content data returned")
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            // Print part of the returned data for debugging
            if let responsePreview = String(data: data.prefix(200), encoding: .utf8) {
                print("File content preview: \(responsePreview)...")
            }
            
            do {
                // Parse to JSON
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Get content field
                    if let content = json["content"] as? String {
                        print("Get file content.")
                        completion(.success(content))
                        return
                    }
                    
                    // Try to get content from the data field
                    if let dataObj = json["data"] as? [String: Any],
                       let content = dataObj["content"] as? String {
                        print("Get content from data field")
                        completion(.success(content))
                        return
                    }
                    
                    // If the "content" field cannot be found, return the entire JSON as a string.
                    print("content field not found，return entire JSON")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        completion(.success(jsonString))
                    } else {
                        completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": "Fail to get file content from response"])))
                    }
                } else {
                    // If it is not JSON，return as text
                    if let content = String(data: data, encoding: .utf8) {
                        print("Not JSON，Return as text")
                        completion(.success(content))
                    } else {
                        completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": "Cannot parse response data"])))
                    }
                }
            } catch {
                print("Parse Error: \(error.localizedDescription)")
                
                // If it is not JSON，return as text
                if let content = String(data: data, encoding: .utf8) {
                    print("Fail to parse JSON，return as text")
                    completion(.success(content))
                } else {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
}
