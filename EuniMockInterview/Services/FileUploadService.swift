import Foundation
import UniformTypeIdentifiers
import PDFKit
import UIKit

enum FileUploadError: Error {
    case invalidFileType
    case fileReadError
    case conversionError
}

@Observable
class FileUploadService {
    static let shared = FileUploadService()
    
    private init() {}
    
    // Supported file types
    let supportedTypes: [UTType] = [
        .plainText,
        .pdf,
        UTType("com.microsoft.word.doc")!,
        UTType("org.openxmlformats.wordprocessingml.document")!
    ]
    
    // Convert file to text
    func extractText(from url: URL) async throws -> String {
        let fileType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
        
        guard let fileType = fileType else {
            throw FileUploadError.invalidFileType
        }
        
        switch fileType {
        case .plainText:
            return try String(contentsOf: url, encoding: .utf8)
            
        case .pdf:
            return try extractTextFromPDF(url: url)
            
        case UTType("com.microsoft.word.doc")!, UTType("org.openxmlformats.wordprocessingml.document")!:
            return try extractTextFromWord(url: url)
            
        default:
            throw FileUploadError.invalidFileType
        }
    }
    
    // Extract text from PDF
    private func extractTextFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw FileUploadError.fileReadError
        }
        
        var extractedText = ""
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            if let pageText = page.string {
                extractedText += pageText + "\n\n"
            }
        }
        
        return extractedText
    }
    
    // Extract text from Word documents
    private func extractTextFromWord(url: URL) throws -> String {
        // For Word documents, we'll use NSAttributedString to extract text
        // This is a simplified approach and may not work perfectly for all Word documents
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        
        do {
            let attributedString = try NSAttributedString(url: url, options: options, documentAttributes: nil)
            return attributedString.string
        } catch {
            print("Error extracting text from Word document: \(error)")
            
            // Fallback to a simpler approach for .docx files
            if url.pathExtension.lowercased() == "docx" {
                return try extractTextFromDocx(url: url)
            }
            
            throw FileUploadError.conversionError
        }
    }
    
    // Fallback method for .docx files
    private func extractTextFromDocx(url: URL) throws -> String {
        // For .docx files, we'll try to extract text using a simpler approach
        // This is a basic implementation and may not work for all .docx files
        
        do {
            // Try to read the file as a zip archive (docx is essentially a zip file)
            let data = try Data(contentsOf: url)
            
            // Look for text content in the document.xml file
            // This is a very simplified approach and may not work for all .docx files
            if let xmlString = String(data: data, encoding: .utf8) {
                // Extract text between <w:t> tags
                let pattern = "<w:t[^>]*>(.*?)</w:t>"
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
                let range = NSRange(xmlString.startIndex..., in: xmlString)
                let matches = regex.matches(in: xmlString, options: [], range: range)
                
                var extractedText = ""
                for match in matches {
                    if let range = Range(match.range(at: 1), in: xmlString) {
                        extractedText += xmlString[range] + " "
                    }
                }
                
                return extractedText
            }
        } catch {
            print("Error extracting text from .docx file: \(error)")
        }
        
        // If all else fails, return a placeholder
        return "Unable to extract text from Word document. Please enter the text manually."
    }
    
    // Upload file to OpenAI
    func uploadToOpenAI(_ url: URL, apiKey: String) async throws -> String {
        let text = try await extractText(from: url)
        
        // TODO: Implement OpenAI file upload using the Responses API
        // This will involve:
        // 1. Creating a file in OpenAI
        // 2. Using the file ID for subsequent API calls
        
        return text
    }
} 