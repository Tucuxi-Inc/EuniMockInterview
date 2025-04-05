import SwiftUI
import SwiftData

struct NewCandidateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var resume = ""
    @State private var jobDescription = ""
    @State private var companyName = ""
    @State private var interviewerName = ""
    @State private var resumeFile: String?
    @State private var jobDescriptionFile: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Company/Firm Information") {
                    TextField("Company Name", text: $companyName)
                    TextField("Interviewer Name (Optional)", text: $interviewerName)
                }
                
                Section("Job Details") {
                    TextEditor(text: $jobDescription)
                        .frame(height: 100)
                    
                    FileUploadView(title: "Upload Job Description") { content in
                        jobDescriptionFile = content
                        if !content.isEmpty {
                            jobDescription = content
                        }
                    }
                }
                
                Section("Your Information") {
                    TextField("Name", text: $name)
                }
                
                Section("Resume") {
                    TextEditor(text: $resume)
                        .frame(height: 200)
                    
                    FileUploadView(title: "Upload Resume") { content in
                        resumeFile = content
                        if !content.isEmpty {
                            resume = content
                        }
                    }
                }
            }
            .navigationTitle("New Interview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCandidate()
                    }
                    .disabled(name.isEmpty || (resume.isEmpty && resumeFile == nil) || (jobDescription.isEmpty && jobDescriptionFile == nil) || companyName.isEmpty)
                }
            }
        }
    }
    
    private func addCandidate() {
        let candidate = Candidate(
            name: name,
            resume: resume,
            jobDescription: jobDescription,
            companyName: companyName,
            resumeFile: resumeFile,
            jobDescriptionFile: jobDescriptionFile,
            interviewerName: interviewerName.isEmpty ? nil : interviewerName
        )
        
        modelContext.insert(candidate)
        dismiss()
    }
}

#Preview {
    NewCandidateView()
        .modelContainer(for: Candidate.self, inMemory: true)
} 