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
    
    // 싱글톤 참조를 직접 사용하지 말고 필요한 경우에만 접근
    private var viewModel: ChatViewModel { ChatViewModel.shared }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                // AI 아바타
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 30, height: 30)
                    .background(Color(.systemOrange).opacity(0.15))
                    .clipShape(Circle())
            } else {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // 메시지 라벨
                HStack {
                    if !message.isUser {
                        Text("Assistant")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    } else {
                        Spacer()
                        Text("You")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                
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
                    SelectableText(text: message.content)
                        .padding(20)
                        .background(Color(.systemOrange).opacity(0.15))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemOrange).opacity(0.3), lineWidth: 1)
                        )

                    HStack {
                        HoverImageButton(imageName: "arrow.counterclockwise.square") {
                            Task {
                                await handleRetryAction()
                            }
                        }
                        HoverImageButton(imageName: "square.on.square"){
                            Task {
                                await handleCopyAction()
                            }
                        }
                        HoverImageButton(imageName: "square.and.arrow.down"){
                            Task {
                                await handleShareAction()
                            }
                        }
                        HoverImageButton(imageName: "trash"){
                            Task { @MainActor in
                                showingDeleteAlert = true
                            }
                        }
                    }
                    .foregroundColor(.gray)
                } else {
                    SelectableText(text: message.content)
                        .padding(20)
                        .background(Color(.systemBlue).opacity(0.1))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemBlue).opacity(0.3), lineWidth: 1)
                        )

                }
            }

            if !message.isUser {
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            }
                }
            }
            
            if message.isUser {
                // 사용자 아바타
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 30, height: 30)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.leading, message.isUser ? 40 : 0)
        .padding(.trailing, message.isUser ? 0 : 40)
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
                Task {
                    await handleDeleteAction()
                }
            }
        } message: {
            Text("l_del_question".localized)
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleRetryAction() async {
        guard !message.isUser else { return }
        
        let vm = ChatViewModel.shared
        if let currentIndex = vm.messages.firstIndex(where: { $0.id == message.id }),
           currentIndex > 0 {
            let previousMessage = vm.messages[currentIndex - 1]
            if previousMessage.isUser {
                await MainActor.run {
                    vm.startNewChat()
                    vm.messageText = previousMessage.content
                    if let image = previousMessage.image {
                        vm.selectedImage = image
                    }
                    vm.shouldFocusTextField = true
                }
            }
        }
    }
    
    private func handleCopyAction() async {
        await MainActor.run {
            copyToClipboard()
        }
    }
    
    private func handleShareAction() async {
        await MainActor.run {
            shareContent()
        }
    }
    
    private func handleDeleteAction() async {
        await deleteMessage()
    }
    
    private func showTemporaryAlert(_ message: String) {
        Task { @MainActor in
            alertMessage = message
            withAnimation {
                showAlert = true
            }
            
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5초
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
            let vm = ChatViewModel.shared
            if let question = vm.messages.first(where: { $0.id == questionId }) {
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
            Task { @MainActor in
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
    }
    
    private func deleteMessage() {
        Task {
            do {
                // DB에서 먼저 삭제
                try DatabaseManager.shared.delete(id: message.id)
                
                // UI 업데이트는 메인 액터에서 별도로 처리
                let vm = ChatViewModel.shared
                await MainActor.run {
                    // 로컬에서 메시지 제거 (즉시 UI 반영)
                    if let index = vm.messages.firstIndex(where: { $0.id == message.id }) {
                        vm.messages.remove(at: index)
                    }
                }
                
                // 사이드바 새로고침
                await SidebarViewModel.shared.refresh()
                
                // 성공 알림
                await showAlertSafely("l_delete_finish".localized)
            } catch {
                await showAlertSafely("l_delete_fail".localized)
            }
        }
    }
    
    private func showAlertSafely(_ message: String) async {
        await MainActor.run {
            showTemporaryAlert(message)
        }
    }
}
