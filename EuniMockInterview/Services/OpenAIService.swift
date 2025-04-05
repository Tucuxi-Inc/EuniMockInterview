import Foundation
import SwiftUI

/// Errors that can occur when interacting with the OpenAI API
enum OpenAIError: Error {
    /// The response from OpenAI was invalid or couldn't be parsed
    case invalidResponse
    /// OpenAI API returned an error with a specific message
    case apiError(String)
    /// There was an error uploading or processing a file
    case fileUploadError
    /// A network-related error occurred
    case networkError(Error)
}

/// Service responsible for interacting with OpenAI's API to generate interview questions,
/// provide feedback, and analyze STAR method responses.
@Observable
class OpenAIService {
    /// The OpenAI API key used for authentication
    internal let apiKey: String
    /// The ID of the vector database used for semantic search
    internal let vectorDatabaseId: String
    /// The base URL for OpenAI's API endpoints
    private let baseURL = "https://api.openai.com/v1"
    
    /// Initializes the OpenAI service with credentials from the configuration
    /// - Throws: ConfigurationError if the API key or vector database ID cannot be retrieved
    init() throws {
        self.apiKey = try ConfigurationManager.shared.openAIAPIKey
        self.vectorDatabaseId = try ConfigurationManager.shared.vectorDatabaseId
        print("OpenAIService initialized with API key: \(apiKey.prefix(5))... and vector database ID: \(vectorDatabaseId)")
    }
    
    /// Protected initializer for subclasses to use with custom credentials
    /// - Parameters:
    ///   - apiKey: The OpenAI API key
    ///   - vectorDatabaseId: The vector database ID
    internal init(apiKey: String, vectorDatabaseId: String) {
        self.apiKey = apiKey
        self.vectorDatabaseId = vectorDatabaseId
        print("OpenAIService initialized with custom credentials")
    }
    
    /// Creates a file in OpenAI's system for semantic search
    /// - Parameters:
    ///   - content: The text content to be uploaded
    ///   - purpose: The purpose of the file (default: "search")
    /// - Returns: The ID of the created file
    /// - Throws: OpenAIError if the file creation fails
    private func createFile(_ content: String, purpose: String = "search") async throws -> String {
        print("Creating file in OpenAI with purpose: \(purpose)")
        let url = URL(string: "\(baseURL)/files")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Helper function to safely append string data
        func appendString(_ string: String) throws {
            guard let data = string.data(using: .utf8) else {
                throw OpenAIError.fileUploadError
            }
            body.append(data)
        }
        
        // Add file content
        try appendString("--\(boundary)\r\n")
        try appendString("Content-Disposition: form-data; name=\"file\"; filename=\"content.txt\"\r\n")
        try appendString("Content-Type: text/plain\r\n\r\n")
        try appendString(content)
        try appendString("\r\n")
        
        // Add purpose
        try appendString("--\(boundary)\r\n")
        try appendString("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n")
        try appendString("\(purpose)\r\n")
        
        // Add final boundary
        try appendString("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("File creation response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("OpenAI API error: \(message)")
                    throw OpenAIError.apiError(message)
                }
                print("OpenAI API error with status code: \(httpResponse.statusCode)")
                throw OpenAIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let fileResponse = try JSONDecoder().decode(FileResponse.self, from: data)
            print("File created successfully with ID: \(fileResponse.id)")
            return fileResponse.id
        } catch {
            print("Error creating file: \(error)")
            throw OpenAIError.networkError(error)
        }
    }
    
    /// Searches through uploaded files using semantic search
    /// - Parameters:
    ///   - query: The search query
    ///   - fileIds: Array of file IDs to search through
    /// - Returns: Array of search results with content and relevance scores
    /// - Throws: OpenAIError if the search fails
    private func searchFiles(_ query: String, fileIds: [String]) async throws -> [SearchResult] {
        print("Searching files with query: \(query) and file IDs: \(fileIds)")
        let url = URL(string: "\(baseURL)/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let searchRequest = SearchRequest(
            query: query,
            fileIds: fileIds,
            maxResults: 5
        )
        
        request.httpBody = try JSONEncoder().encode(searchRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("Search response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("OpenAI API error: \(message)")
                    throw OpenAIError.apiError(message)
                }
                print("OpenAI API error with status code: \(httpResponse.statusCode)")
                throw OpenAIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            print("Search completed successfully with \(searchResponse.results.count) results")
            return searchResponse.results
        } catch {
            print("Error searching files: \(error)")
            throw OpenAIError.networkError(error)
        }
    }
    
    /// Makes a completion request to OpenAI's chat API
    /// - Parameter prompt: The prompt to send to the API
    /// - Returns: The generated response text
    /// - Throws: OpenAIError if the request fails
    private func makeCompletionRequest(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": "You are an expert interview coach specializing in behavioral interviews using the STAR method."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("Completion response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("OpenAI API error: \(message)")
                    throw OpenAIError.apiError(message)
                }
                print("OpenAI API error with status code: \(httpResponse.statusCode)")
                throw OpenAIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                print("Completion successful")
                return content
            }
            
            throw OpenAIError.invalidResponse
        } catch {
            print("Error making completion request: \(error)")
            throw OpenAIError.networkError(error)
        }
    }
    
    /// Generates personalized behavioral interview questions for a candidate
    /// - Parameter candidate: The candidate to generate questions for
    /// - Returns: Array of interview questions
    /// - Throws: OpenAIError if question generation fails
    open func generateQuestions(for candidate: Candidate) async throws -> [String] {
        print("Generating questions for candidate: \(candidate.name)")
        
        let prompt = """
        Generate 5 behavioral interview questions for a candidate with the following background:
        Name: \(candidate.name)
        Resume: \(candidate.resume)
        Job Description: \(candidate.jobDescription)
        Company: \(candidate.companyName)
        
        Additional context from uploaded files:
        Resume Content: \(candidate.resumeFile ?? "No resume file provided")
        Job Description Content: \(candidate.jobDescriptionFile ?? "No job description file provided")
        
        The questions should:
        1. Be specific to their background and the job
        2. Follow the STAR method format
        3. Focus on key competencies required for the role
        4. Be challenging but fair
        5. Help assess their problem-solving and communication skills
        
        Format each question as a clear, concise sentence ending with a question mark.
        Return exactly 5 questions, one per line.
        """
        
        print("Using prompt: \(prompt)")
        
        let response = try await makeCompletionRequest(prompt: prompt)
        let questions = response.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .prefix(5)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        return Array(questions)
    }
    
    /// Generates feedback for a candidate's answer to an interview question
    /// - Parameter question: The question and answer to provide feedback for
    /// - Returns: Detailed feedback on the answer
    /// - Throws: OpenAIError if feedback generation fails
    open func generateFeedback(for question: Question) async throws -> String {
        print("Generating feedback for question: \(question.text)")
        
        let prompt = """
        Analyze the following interview question and answer using the STAR method (Situation, Task, Action, Result).
        
        Question: \(question.text)
        Answer: \(question.answer ?? "No answer provided")
        
        Provide constructive feedback on:
        1. How well the answer follows the STAR method
        2. Specific strengths in the answer
        3. Areas for improvement
        4. Suggestions for a stronger response
        
        Format your feedback in a clear, concise paragraph.
        """
        
        print("Using prompt: \(prompt)")
        
        return try await makeCompletionRequest(prompt: prompt)
    }
    
    /// Analyzes a candidate's answer using the STAR method components
    /// - Parameter answer: The answer to analyze
    /// - Returns: Scores for each STAR component
    /// - Throws: OpenAIError if analysis fails
    open func analyzeStarComponents(for answer: String) async throws -> StarScore {
        print("Analyzing STAR components for answer")
        
        let prompt = """
        Analyze the following interview answer using the STAR method components:
        
        \(answer)
        
        Score each component on a scale of 0.0 to 1.0:
        - Situation: How well does the answer describe the context and background?
        - Task: How well does the answer describe what needed to be done?
        - Action: How well does the answer describe the actions taken?
        - Result: How well does the answer describe the outcomes and impact?
        
        Return only a simple numerical score for each component in the format: "0.8,0.7,0.9,0.6"
        """
        
        print("Using prompt: \(prompt)")
        
        let response = try await makeCompletionRequest(prompt: prompt)
        let scores = response.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { Double($0) }
        
        guard scores.count == 4 else {
            throw OpenAIError.invalidResponse
        }
        
        return StarScore(
            situation: scores[0],
            task: scores[1],
            action: scores[2],
            result: scores[3]
        )
    }
}

// MARK: - API Response Models

/// Response model for file creation API
struct FileResponse: Codable {
    /// The unique identifier for the created file
    let id: String
    /// The type of object (always "file")
    let object: String
    /// The size of the file in bytes
    let bytes: Int
    /// Unix timestamp of when the file was created
    let created_at: Int
    /// The name of the file
    let filename: String
    /// The purpose of the file (e.g., "search")
    let purpose: String
}

/// Request model for file search API
struct SearchRequest: Codable {
    /// The search query
    let query: String
    /// Array of file IDs to search through
    let fileIds: [String]
    /// Maximum number of results to return
    let maxResults: Int
}

/// Response model for file search API
struct SearchResponse: Codable {
    /// Array of search results
    let results: [SearchResult]
}

/// Model representing a single search result
struct SearchResult: Codable {
    /// The content of the search result
    let content: String
    /// The relevance score of the result (0.0 to 1.0)
    let score: Double
    /// Additional metadata about the result
    let metadata: [String: String]
} 
