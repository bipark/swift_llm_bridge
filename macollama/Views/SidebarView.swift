import SwiftUI

struct ChatTitle: Identifiable, Equatable {
    let id: Int
    let groupId: String
    let question: String
    let answer: String?
    let created: String
    let engine: String
    let image: String?
    let title: String?
    let provider: String?
    let model: String?
    
    var formattedDate: String {
        let dateFormatter = ISO8601DateFormatter()
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        if let date = dateFormatter.date(from: created) {
            return outputFormatter.string(from: date)
        }
        return created
    }
    
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return question.isEmpty ? "Untitled Chat" : question
    }
    
    static func == (lhs: ChatTitle, rhs: ChatTitle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.groupId == rhs.groupId &&
               lhs.question == rhs.question &&
               lhs.answer == rhs.answer &&
               lhs.created == rhs.created &&
               lhs.engine == rhs.engine &&
               lhs.image == rhs.image &&
               lhs.title == rhs.title &&
               lhs.provider == rhs.provider &&
               lhs.model == rhs.model
    }
}

struct SidebarView: View {
    @ObservedObject private var viewModel = SidebarViewModel.shared
    @ObservedObject private var chatViewModel = ChatViewModel.shared
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: ChatTitle?
    @State private var selectedGroupId: String?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingRenameSheet = false
    @State private var itemToRename: ChatTitle?
    @State private var renameText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("l_search".localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .onChange(of: searchText) { _, newValue in
                        isSearching = !newValue.isEmpty
                        Task {
                            if newValue.isEmpty {
                                await viewModel.loadChatTitles()
                            } else {
                                await viewModel.searchChatTitles(keyword: newValue)
                            }
                        }
                    }
                
                if isSearching {
                    Button(action: {
                        searchText = ""
                        isSearching = false
                        Task {
                            await viewModel.loadChatTitles()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                Group {
                    if #available(macOS 12, *) {
                        RoundedRectangle(cornerRadius: 8).fill(.regularMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1))
                    }
                }
            )
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(Edge.Set.vertical, 4)
            
            ScrollViewReader { proxy in
                List(viewModel.chatTitles, selection: $selectedGroupId) { chat in
                    HStack(spacing: 12) {
                        if let imageBase64 = chat.image,
                           let imageData = Data(base64Encoded: imageBase64),
                           let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.displayTitle)
                                .lineLimit(2)
                                .font(.headline)
                            
                            HStack {
                                Text(chat.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                        .padding(Edge.Set.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedGroupId = chat.groupId
                            chatViewModel.loadChat(groupId: chat.groupId)
                        }
                        
                        Spacer()
                        HStack(spacing: 4) {
                            HoverImageButton(imageName: "pencil", size: 14, btnColor: .blue) {
                                itemToRename = chat
                                renameText = chat.question
                                showingRenameSheet = true
                            }
                            HoverImageButton(imageName: "trash", size: 14, btnColor : .red) {
                                itemToDelete = chat
                                showingDeleteAlert = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(Edge.Set.vertical, 2)
                    .padding(Edge.Set.vertical, 4)
                    .listRowBackground(chat.groupId == selectedGroupId ? Color.blue.opacity(0.08) : Color.clear)
                }
                .frame(maxHeight: .infinity)
                .listStyle(.inset)
                .listRowSeparator(.visible)
                .listRowSeparatorTint(.secondary)
                .task {
                    await viewModel.loadChatTitles()
                    if let firstChat = viewModel.chatTitles.first {
                        selectedGroupId = firstChat.groupId
                        chatViewModel.loadChat(groupId: firstChat.groupId)
                    }
                }
                .onChange(of: viewModel.chatTitles) { _, newTitles in
                    if let firstId = newTitles.first?.id {
                        withAnimation {
                            proxy.scrollTo(firstId, anchor: .top)
                        }
                    }
                }
                .onChange(of: chatViewModel.chatId) { _, newId in
                    selectedGroupId = newId.uuidString
                }
                .alert("l_del_question".localized, isPresented: $showingDeleteAlert) {
                    Button("l_cancel".localized, role: .cancel) { }
                    Button("l_delete".localized, role: .destructive) {
                        if let chat = itemToDelete {
                            Task {
                                try? await viewModel.deleteChat(groupId: chat.groupId)
                                if chatViewModel.chatId.uuidString == chat.groupId {
                                    chatViewModel.startNewChat()
                                }
                            }
                        }
                    }
                } message: {
                    Text("l_del_question".localized)
                }
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingRenameSheet) {
            RenameChatView(
                currentName: renameText,
                onRename: { newName in
                    if let chat = itemToRename {
                        Task {
                            do {
                                try await viewModel.renameChat(groupId: chat.groupId, newName: newName)
                            } catch {
                            }
                        }
                    }
                },
                onCancel: {
                    renameText = ""
                    itemToRename = nil
                }
            )
        }
    }
}

