//
//  MessageRowView.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import SwiftUI

struct MessageRowView: View {
    let message: ChatMessage
    var onRate: (Int) -> Void

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack {
                if message.role == .assistant {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                }
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(message.text)
                .padding(12)
                .background(message.role == .user ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                RatingControl(rating: message.rating ?? 0, onRate: onRate)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal)
    }
}

struct RatingControl: View {
    let rating: Int
    var onRate: (Int) -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button {
                onRate(1)
            } label: {
                Text("👍")
                    .font(.title3)
                    .opacity(rating == 1 ? 1 : 0.4)
            }

            Button {
                onRate(-1)
            } label: {
                Text("👎")
                    .font(.title3)
                    .opacity(rating == -1 ? 1 : 0.4)
            }
        }
        .buttonStyle(.plain)
    }
}
