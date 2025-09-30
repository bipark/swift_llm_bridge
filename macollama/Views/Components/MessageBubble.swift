import SwiftUI
import MarkdownUI

extension Theme {
    static let customSmall = Theme()
        .text {
            FontSize(14)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(12)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(20)
                    FontWeight(.bold)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(18)
                    FontWeight(.semibold)
                }
        }
}

struct SelectableText: View {
    let text: String
    
    var body: some View {
        Markdown(text)
            .markdownTheme(.customSmall)
            .textSelection(.enabled)
            .contextMenu {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                }) {
                    Label("l_copy".localized, systemImage: "doc.on.doc")
                }
            }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingDeleteAlert = false
    @StateObject private var viewModel = ChatViewModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = message.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .cornerRadius(8)
            }
            
            if !message.isUser && message.content.trimmingCharacters(in: .whitespacesAndNewlines) == "..." {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("l_waiting".localized)
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .frame(height: 20)
            } else {
                if !message.isUser {
                    HStack {
                        Text("Model Response")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        Spacer()
                    }
                    
                    SelectableText(text: message.content)
                        .padding(20)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        HoverImageButton(imageName: "arrow.counterclockwise.square") {
                            if !message.isUser {
                                if let currentIndex = viewModel.messages.firstIndex(where: { $0.id == message.id }),
                                   currentIndex > 0 {
                                    let previousMessage = viewModel.messages[currentIndex - 1]
                                    if previousMessage.isUser {
                                        viewModel.startNewChat()
                                        viewModel.messageText = previousMessage.content
                                        if let image = previousMessage.image {
                                            viewModel.selectedImage = image
                                        }
                                        viewModel.shouldFocusTextField = true
                                    }
                                }
                            }
                        }
                        HoverImageButton(imageName: "square.on.square"){
                            copyToClipboard()
                        }
                        HoverImageButton(imageName: "square.and.arrow.down"){
                            shareContent()
                        }
                        HoverImageButton(imageName: "trash"){
                            showingDeleteAlert = true
                        }
                    }
                    .foregroundColor(.gray)
                } else {
                    HStack {
                        Spacer()
                        Text("You")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                    
                    SelectableText(text: message.content)
                        .padding(20)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                }
            }

            if !message.isUser {
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .overlay {
            if showAlert {
                GeometryReader { geometry in
                    CenterAlertView(message: alertMessage)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showAlert)
        .alert("l_delete_message".localized, isPresented: $showingDeleteAlert) {
            Button("l_cancel".localized, role: .cancel) { }
            Button("l_delete".localized, role: .destructive) {
                deleteMessage()
            }
        } message: {
            Text("l_del_question".localized)
        }
    }
    
    private func showTemporaryAlert(_ message: String) {
        alertMessage = message
        withAnimation {
            showAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showAlert = false
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
        showTemporaryAlert("l_copy_finish".localized)
    }
    
    private func shareContent() {
        let picker = NSSavePanel()
        picker.title = "l_save_conv".localized
        
        let questionContent: String
        if !message.isUser {
            let questionId = message.id - 1
            if let question = viewModel.messages.first(where: { $0.id == questionId }) {
                questionContent = question.content
            } else {
                questionContent = ""
            }
        } else {
            questionContent = message.content
        }
        
        let fileName = questionContent
            .components(separatedBy: .whitespacesAndNewlines)
            .prefix(10)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        picker.nameFieldStringValue = "\(fileName).txt"
        picker.allowedContentTypes = [.text]
        
        picker.begin { response in
            if response == .OK, let url = picker.url {
                do {
                    let content = """
                    [Q] :
                    \(questionContent)
                    
                    [A] :
                    \(message.content)
                    """
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    showTemporaryAlert("l_save_finish".localized)
                } catch {
                    showTemporaryAlert("l_save_fail".localized)
                }
            }
        }
    }
    
    private func deleteMessage() {
        Task {
            do {
                try DatabaseManager.shared.delete(id: message.id)
                viewModel.loadChat(groupId: viewModel.chatId.uuidString)
                SidebarViewModel.shared.refresh()
                showTemporaryAlert("l_delete_finish".localized)
            } catch {
                showTemporaryAlert("l_delete_fail".localized)
            }
        }
    }
} 
