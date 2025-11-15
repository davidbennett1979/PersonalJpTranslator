//
//  ChatView.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

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
            .onChange(of: viewModel.messages) { _, newMessages in
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
            TextField("Ask for translations, feedback, or clarity…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)

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
