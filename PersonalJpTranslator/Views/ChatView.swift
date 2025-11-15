//
//  ChatView.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                personalizationBanner
                messageList
                inputBar
            }
            .padding(.horizontal)
            .padding(.bottom)
            .navigationTitle("JP Translator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
        .alert("Error",
               isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
               ),
               actions: {},
               message: { Text(viewModel.errorMessage ?? "") })
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageRowView(message: message) { rating in
                            viewModel.rate(message: message, rating: rating)
                        }
                        .id(message.id)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: viewModel.messages, initial: true) { _, newMessages in
                guard let last = newMessages.last else { return }
                withAnimation {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var personalizationBanner: some View {
        HStack(alignment: .top) {
            Image(systemName: "person.badge.key.fill")
                .foregroundStyle(.blue)
            Text(viewModel.personalizationSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.inputText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if viewModel.inputText.isEmpty {
                    Text("Ask for translations, feedback, or clarity…")
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                Spacer()
                Button(action: viewModel.send) {
                    Label("Send", systemImage: "paperplane.fill")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(viewModel.isLoading || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        let store = AppStateStore()
        let viewModel = ChatViewModel(store: store, client: OpenAIClient())
        ChatView(viewModel: viewModel)
    }
}
