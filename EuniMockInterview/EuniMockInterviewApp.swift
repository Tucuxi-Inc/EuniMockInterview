//
//  EuniMockInterviewApp.swift
//  EuniMockInterview
//
//  Created by Kevin Keller on 4/3/25.
//

import SwiftUI
import SwiftData

@main
struct EuniMockInterviewApp: App {
    @State private var openAIService: OpenAIService
    
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Candidate.self,
            Interview.self,
            Question.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        do {
            self._openAIService = State(initialValue: try OpenAIService())
            print("OpenAIService initialized successfully")
        } catch {
            print("Error initializing OpenAIService: \(error)")
            // Create a mock service for development
            self._openAIService = State(initialValue: MockOpenAIService(mock: true))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(openAIService)
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Mock implementation of OpenAIService for development and testing
class MockOpenAIService: OpenAIService {
    override init() throws {
        try super.init()
        print("MockOpenAIService initialized with real credentials")
    }
    
    /// Convenience initializer for mock service with dummy credentials
    init(mock: Bool) {
        super.init(apiKey: "mock-api-key", vectorDatabaseId: "mock-vector-db-id")
        print("MockOpenAIService initialized with mock credentials")
    }
    
    override func generateQuestions(for candidate: Candidate) async throws -> [String] {
        print("Mock: Generating questions for \(candidate.name)")
        return [
            "Tell me about a time when you had to solve a complex problem.",
            "Describe a situation where you had to work with a difficult team member.",
            "Give an example of a project you managed from start to finish.",
            "Tell me about a time when you had to make a difficult decision.",
            "Describe a situation where you had to adapt to significant changes."
        ]
    }
    
    override func generateFeedback(for question: Question) async throws -> String {
        print("Mock: Generating feedback for question")
        return """
        Your answer demonstrates good use of the STAR method. Here are some specific points:
        
        Strengths:
        - Clear situation description
        - Good explanation of actions taken
        - Quantifiable results provided
        
        Areas for Improvement:
        - Could provide more context about the initial challenge
        - Consider adding more specific metrics
        - Include lessons learned
        
        Suggestions:
        1. Start with a brief overview of the situation
        2. Include specific numbers and metrics
        3. End with key learnings and takeaways
        """
    }
    
    override func analyzeStarComponents(for answer: String) async throws -> StarScore {
        print("Mock: Analyzing STAR components")
        return StarScore(
            situation: 0.8,
            task: 0.7,
            action: 0.9,
            result: 0.6
        )
    }
}
