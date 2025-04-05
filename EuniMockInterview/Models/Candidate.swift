import Foundation
import SwiftData

@Model
class Candidate {
    var name: String
    var resume: String
    var jobDescription: String
    var companyName: String
    var resumeFile: String?
    var jobDescriptionFile: String?
    var interviewerName: String?
    var interviews: [Interview]
    var createdAt: Date
    
    init(
        name: String,
        resume: String = "",
        jobDescription: String = "",
        companyName: String = "",
        resumeFile: String? = nil,
        jobDescriptionFile: String? = nil,
        interviewerName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.resume = resume
        self.jobDescription = jobDescription
        self.companyName = companyName
        self.resumeFile = resumeFile
        self.jobDescriptionFile = jobDescriptionFile
        self.interviewerName = interviewerName
        self.interviews = []
        self.createdAt = createdAt
    }
} 