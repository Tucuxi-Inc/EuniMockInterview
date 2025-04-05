import Foundation
import SwiftUI
import SwiftData

@MainActor
class InterviewViewModel: ObservableObject {
    private let openAIService: OpenAIService
    var modelContext: ModelContext
    
    @Published var currentInterview: Interview?
    @Published var currentQuestionIndex: Int = 0
    @Published var isInterviewComplete: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        do {
            self.openAIService = try OpenAIService()
        } catch {
            fatalError("Failed to initialize OpenAIService: \(error)")
        }
    }
    
    var currentQuestion: Question? {
        guard let interview = currentInterview,
              currentQuestionIndex < interview.questions.count else {
            return nil
        }
        return interview.questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard let interview = currentInterview else { return 0 }
        return Double(currentQuestionIndex) / Double(interview.questions.count)
    }
    
    func startInterview(for candidate: Candidate) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Validate candidate information
            guard !candidate.name.isEmpty else {
                throw NSError(domain: "InterviewViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Candidate name is required"])
            }
            
            guard !candidate.resume.isEmpty || candidate.resumeFile != nil else {
                throw NSError(domain: "InterviewViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Resume information is required"])
            }
            
            guard !candidate.jobDescription.isEmpty || candidate.jobDescriptionFile != nil else {
                throw NSError(domain: "InterviewViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Job description information is required"])
            }
            
            // Generate questions
            let questions = try await openAIService.generateQuestions(for: candidate)
            
            // Create interview
            let interview = Interview(candidate: candidate)
            interview.questions = questions.enumerated().map { index, text in 
                Question(interview: interview, text: text, order: index)
            }
            
            // Save to database
            currentInterview = interview
            modelContext.insert(interview)
            try modelContext.save()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to start interview: \(error.localizedDescription)"
            print("Error starting interview: \(error)")
        }
    }
    
    func submitAnswer(_ answer: String) async {
        guard let question = currentQuestion else { return }
        
        do {
            question.answer = answer
            let feedback = try await openAIService.generateFeedback(for: question)
            question.feedback = feedback
            question.starScore = try await openAIService.analyzeStarComponents(for: answer)
            
            currentQuestionIndex += 1
            if currentQuestionIndex >= currentInterview?.questions.count ?? 0 {
                isInterviewComplete = true
                // Generate a summary of the interview
                let summary = """
                Interview completed with \(currentInterview?.candidate.name ?? "candidate")
                Total Questions: \(currentInterview?.questions.count ?? 0)
                Overall Score: \(Int(calculateOverallScore() * 100))%
                
                Key Strengths:
                - Strong problem-solving skills
                - Clear communication
                - Good use of STAR method
                
                Areas for Improvement:
                - Add more quantifiable results
                - Provide more specific examples
                - Structure answers more concisely
                """
                currentInterview?.feedback = summary
                currentInterview?.overallScore = calculateOverallScore()
            }
            
            try modelContext.save()
        } catch {
            errorMessage = "Failed to submit answer: \(error.localizedDescription)"
        }
    }
    
    private func calculateOverallScore() -> Double {
        guard let interview = currentInterview,
              !interview.questions.isEmpty else { return 0 }
        
        let scores = interview.questions.compactMap { $0.starScore }
        if scores.isEmpty { return 0 }
        
        let totalScore = scores.reduce(0.0) { sum, score in
            sum + (score.situation + score.task + score.action + score.result) / 4.0
        }
        return totalScore / Double(scores.count)
    }
} 