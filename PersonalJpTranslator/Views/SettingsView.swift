import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Personalization") {
                    Text(viewModel.userProfile.learningSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Engagement Stats") {
                    LabeledContent("Questions Logged", value: "\(viewModel.totalQuestions)")
                    LabeledContent("👍 Likes", value: "\(viewModel.likedAnswers)")
                    LabeledContent("👎 Dislikes", value: "\(viewModel.dislikedAnswers)")
                }

                Section("Skill Tree") {
                    ForEach(viewModel.skillCategories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(category.category.title, systemImage: category.category.icon)
                                .font(.headline)
                            Text(category.category.flavorText)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(category.skills) { skill in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(skill.skill.title)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(skill.score)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    ProgressView(value: skill.progress)
                                        .tint(.blue)
                                    Text(skill.skill.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("Highlights") {
                    Text(viewModel.highlightSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Maintenance") {
                    Button(role: .destructive) {
                        viewModel.clearConversation()
                    } label: {
                        Label("Clear Conversation History", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                    }

                    Button(role: .destructive) {
                        viewModel.resetPersonalization()
                    } label: {
                        Label("Reset Personalization Memory", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Learning Settings")
        }
    }
}

#Preview {
    let store = AppStateStore()
    let viewModel = SettingsViewModel(store: store)
    SettingsView()
        .environmentObject(viewModel)
}
