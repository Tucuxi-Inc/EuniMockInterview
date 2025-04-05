import SwiftUI
import UniformTypeIdentifiers

struct FileUploadView: View {
    @State private var isFilePickerPresented = false
    @State private var selectedFile: URL?
    @State private var fileContent: String?
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    let title: String
    let onFileSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Button(action: {
                isFilePickerPresented = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text(selectedFile == nil ? "Upload File" : "Change File")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .disabled(isProcessing)
            
            if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing file...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let selectedFile = selectedFile {
                Text(selectedFile.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: FileUploadService.shared.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                selectedFile = url
                isProcessing = true
                errorMessage = nil
                
                Task {
                    do {
                        let content = try await FileUploadService.shared.extractText(from: url)
                        fileContent = content
                        onFileSelected(content)
                        errorMessage = nil
                    } catch {
                        errorMessage = "Error reading file: \(error.localizedDescription)"
                    }
                    isProcessing = false
                }
                
            case .failure(let error):
                errorMessage = "Error selecting file: \(error.localizedDescription)"
            }
        }
    }
} 