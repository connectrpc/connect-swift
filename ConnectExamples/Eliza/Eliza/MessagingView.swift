import Combine
import SwiftUI

struct MessagingView<ViewModel: MessagingViewModel>: View {
    @State private var currentMessage = ""
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var viewModel: ViewModel

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
                    .onSubmit(self.sendMessage)
                    .submitLabel(.send)
                Button("Send", action: self.sendMessage)
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
