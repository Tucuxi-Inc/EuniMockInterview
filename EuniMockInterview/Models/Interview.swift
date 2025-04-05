import Foundation
import SwiftData

@Model
final class Interview {
    var candidate: Candidate
    var questions: [Question]
    var startTime: Date
    var endTime: Date?
    var overallScore: Double?
    var feedback: String?
    
    init(candidate: Candidate) {
        self.candidate = candidate
        self.questions = []
        self.startTime = Date()
    }
} 