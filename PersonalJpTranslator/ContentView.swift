//
//  ContentView.swift
//  PersonalJpTranslator
//
//  Created by David Bennett on 11/14/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    var body: some View {
        TabView {
            ChatView(viewModel: chatViewModel)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }

            SettingsView()
                .environmentObject(settingsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    let store = AppStateStore()
    let chatVM = ChatViewModel(store: store, client: OpenAIClient())
    let settingsVM = SettingsViewModel(store: store)
    ContentView()
        .environmentObject(chatVM)
        .environmentObject(settingsVM)
}
