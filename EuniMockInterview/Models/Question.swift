import Foundation
import SwiftData

@Model
final class Question {
    var interview: Interview
    var text: String
    var answer: String?
    var feedback: String?
    var starScore: StarScore?
    var order: Int
    
    init(interview: Interview, text: String, order: Int) {
        self.interview = interview
        self.text = text
        self.order = order
    }
}

struct StarScore: Codable {
    var situation: Double
    var task: Double
    var action: Double
    var result: Double
    
    var average: Double {
        (situation + task + action + result) / 4.0
    }
} 