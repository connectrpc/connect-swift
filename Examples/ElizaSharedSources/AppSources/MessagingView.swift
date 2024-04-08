// Copyright 2022-2024 The Connect Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Combine
import SwiftUI

struct MessagingView<ViewModel: MessagingViewModel>: View {
    @State private var currentMessage = ""
    @ObservedObject private var viewModel: ViewModel

    @Environment(\.presentationMode)
    private var presentationMode

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            ScrollViewReader { listView in
                // ScrollViewReader crashes in iOS 16 with ListView:
                // https://developer.apple.com/forums/thread/712510
                // Using ScrollView + ForEach as a workaround.
                ScrollView {
                    ForEach(self.viewModel.messages) { message in
                        VStack {
                            switch message.author {
                            case .user:
                                HStack {
                                    Spacer()
                                    Text("You")
                                        .foregroundColor(.gray)
                                        .fontWeight(.semibold)
                                }
                                HStack {
                                    Spacer()
                                    Text(message.message)
                                        .multilineTextAlignment(.trailing)
                                }
                            case .eliza:
                                HStack {
                                    Text("Eliza")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                HStack {
                                    Text(message.message)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                            }
                        }
                        .id(message.id)
                    }
                }
                .onChange(of: self.viewModel.messages.count) { messageCount in
                    listView.scrollTo(self.viewModel.messages[messageCount - 1].id)
                }
            }

            HStack {
                TextField("Write your message...", text: self.$currentMessage)
                    .onSubmit { self.sendMessage() }
                    .submitLabel(.send)
                Button("Send", action: { self.sendMessage() })
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("End Chat") {
                    self.viewModel.endChat()
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func sendMessage() {
        let messageToSend = self.currentMessage
        if messageToSend.isEmpty {
            return
        }

        Task { await self.viewModel.send(messageToSend) }
        self.currentMessage = ""
    }
}
