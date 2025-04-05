import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var candidates: [Candidate]
    @State private var showingNewCandidateSheet = false
    @State private var selectedCandidate: Candidate?
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(candidates) { candidate in
                        CandidateRow(candidate: candidate)
                            .onTapGesture {
                                selectedCandidate = candidate
                            }
                    }
                    .onDelete(perform: deleteCandidates)
                }
                
                Button(action: { showingNewCandidateSheet = true }) {
                    Text("Set up a New Interview")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Euni™ Mock Interview")
            .sheet(isPresented: $showingNewCandidateSheet) {
                NewCandidateView()
            }
            .sheet(item: $selectedCandidate) { candidate in
                InterviewView(candidate: candidate)
            }
        }
    }
    
    private func deleteCandidates(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(candidates[index])
            }
        }
    }
}

struct CandidateRow: View {
    let candidate: Candidate
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(candidate.name)
                .font(.headline)
            Text(candidate.companyName)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Candidate.self, inMemory: true)
} 
