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
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(skill.skill.title)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(verbatim: String(format: "%+d", skill.score))
                                            .font(.caption)
                                            .foregroundStyle(skill.isPositive ? .green : .pink)
                                    }
                                    SkillMeterView(relativeProgress: skill.relativeProgress)
                                        .frame(height: 12)
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

struct SkillMeterView: View {
    let relativeProgress: Double // -1...1

    private var positiveGradient: LinearGradient {
        LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)
    }

    private var negativeGradient: LinearGradient {
        LinearGradient(colors: [.pink, .purple], startPoint: .trailing, endPoint: .leading)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let mid = width / 2
            let height = geo.size.height

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: width, height: height)

                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 1, height: height)
                    .position(x: mid, y: height / 2)

                if relativeProgress != 0 {
                    let fillWidth = mid * abs(relativeProgress)
                    let offsetX = relativeProgress >= 0 ? mid : mid - fillWidth

                    Capsule()
                        .fill(relativeProgress >= 0 ? positiveGradient : negativeGradient)
                        .frame(width: fillWidth, height: height)
                        .offset(x: offsetX)
                }
            }
        }
    }
}
