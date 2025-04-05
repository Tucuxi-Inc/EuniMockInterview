import SwiftUI
import SwiftData

struct InterviewView: View {
    @Environment(OpenAIService.self) private var openAIService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: InterviewViewModel
    @State private var answer: String = ""
    @State private var isRecording = false
    let candidate: Candidate
    
    init(candidate: Candidate) {
        self.candidate = candidate
        // Initialize the StateObject with a temporary modelContext
        // The real modelContext will be injected when the view is created
        let tempContainer = try! ModelContainer(for: Candidate.self, Interview.self, Question.self)
        _viewModel = StateObject(wrappedValue: InterviewViewModel(modelContext: ModelContext(tempContainer)))
    }
    
    var body: some View {
        NavigationStack {
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Setting up your interview...")
                        .font(.headline)
                        .padding()
                    Text("This may take a moment as we generate personalized questions based on your background.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Interview Setup")
            } else if let question = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    // Progress indicator
                    ProgressView(value: viewModel.progress)
                        .padding()
                    
                    // Question
                    Text(question.text)
                        .font(.title2)
                        .padding()
                    
                    // Answer input
                    TextEditor(text: $answer)
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                        .padding()
                    
                    // Recording button
                    Button(action: {
                        isRecording.toggle()
                        // TODO: Implement audio recording
                    }) {
                        Label(
                            isRecording ? "Stop Recording" : "Start Recording",
                            systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    
                    // Submit button
                    Button("Submit Answer") {
                        Task {
                            await viewModel.submitAnswer(answer)
                            answer = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(answer.isEmpty)
                }
                .padding()
                .navigationTitle("Interview in Progress")
            } else if viewModel.isInterviewComplete {
                InterviewCompleteView(interview: viewModel.currentInterview!)
            } else {
                VStack(spacing: 20) {
                    Text("Ready to Start Interview")
                        .font(.headline)
                    
                    Text("Your interview is ready to begin. The AI will generate questions based on your resume and job description.")
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Start Interview") {
                        Task {
                            await viewModel.startInterview(for: candidate)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("Interview Setup")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            // Update the viewModel's modelContext with the real one from the environment
            viewModel.modelContext = modelContext
        }
    }
}

struct InterviewCompleteView: View {
    let interview: Interview
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Interview Complete!")
                    .font(.title)
                    .padding()
                
                if let score = interview.overallScore {
                    Text("Overall Score: \(Int(score * 100))%")
                        .font(.headline)
                }
                
                Text("Feedback")
                    .font(.headline)
                
                Text(interview.feedback ?? "No feedback available")
                    .padding()
                
                ForEach(interview.questions) { question in
                    QuestionFeedbackView(question: question)
                }
            }
            .padding()
        }
    }
}

struct QuestionFeedbackView: View {
    let question: Question
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.text)
                .font(.headline)
            
            if let answer = question.answer {
                Text("Your Answer:")
                    .font(.subheadline)
                Text(answer)
            }
            
            if let feedback = question.feedback {
                Text("Feedback:")
                    .font(.subheadline)
                Text(feedback)
            }
            
            if let score = question.starScore {
                HStack {
                    Text("STAR Score:")
                    Spacer()
                    let averageScore = (score.situation + score.task + score.action + score.result) / 4.0
                    Text("\(Int(averageScore * 100))%")
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    InterviewView(candidate: Candidate(
        name: "John Doe",
        resume: "Sample resume",
        jobDescription: "Sample job description",
        companyName: "Sample Company",
        interviewerName: "Jane Smith"
    ))
    .modelContainer(for: Candidate.self, inMemory: true)
} 