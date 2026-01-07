//
//  ElementChatView.swift
//  ephemera
//
//  A chat interface for exploring specific chart elements, placements,
//  or readings. More flexible than ReadingChatView, supporting various
//  context types.
//
//  Created by Kunal_Datta on 06/01/26.
//

import SwiftUI

/// A flexible chat view for exploring chart elements, placements, or readings
struct ElementChatView: View {
    let elementTitle: String
    let elementContent: String
    let chart: BirthChart
    let profile: UserProfile
    let contexts: [UserContext]
    let accentColor: Color
    var existingConversation: ReadingConversation? = nil
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var conversationManager = ConversationManager.shared
    
    @State private var conversation: ReadingConversation?
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showingMessagesSheet: Bool = false
    @FocusState private var isInputFocused: Bool
    
    // Scroll state
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Context card
                        contextCard
                        
                        // Messages
                        ForEach(messages) { message in
                            MessageBubble(message: message, accentColor: accentColor)
                                .id(message.id)
                        }
                        
                        // Loading indicator
                        if isLoading {
                            HStack {
                                TypingIndicator(color: accentColor)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .id("loading")
                        }
                        
                        Color.clear.frame(height: 20).id("bottom")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .onAppear { scrollProxy = proxy }
                .onChange(of: messages.count) { _, _ in scrollToBottom() }
            }
            .frame(maxWidth: .infinity)
            
            // Input area
            if !conversationManager.canSendMessage {
                // Out of messages prompt
                outOfMessagesView
            } else {
                inputArea
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.04, green: 0.04, blue: 0.09))
        .onAppear { startConversation() }
        .sheet(isPresented: $showingMessagesSheet) {
            MessagesSheetView(accentColor: accentColor)
        }
    }
    
    // MARK: - Conversation Management
    
    private func startConversation() {
        if let existing = existingConversation {
            // Continue existing conversation
            // If it was closed (previously summarized), reopen it for continuation
            if existing.isClosed {
                let reopened = ReadingConversation(
                    id: existing.id,
                    userId: existing.userId,
                    timeframe: existing.timeframe,
                    readingContent: existing.readingContent,
                    readingDate: existing.readingDate,
                    messages: existing.messages,
                    createdAt: existing.createdAt,
                    updatedAt: Date(),
                    elementTitle: existing.elementTitle,
                    summary: nil,  // Clear old summary
                    isClosed: false  // Reopen for continuation
                )
                conversation = reopened
                messages = reopened.messages
            } else {
                conversation = existing
                messages = existing.messages
            }
        } else {
            // Start new conversation
            let newConversation = ReadingConversation(
                userId: profile.id,
                timeframe: .day, // Default timeframe for element chats
                readingContent: elementContent,
                readingDate: DateUtility.today,
                elementTitle: elementTitle
            )
            conversation = newConversation
        }
    }
    
    private func handleDismiss() {
        // Save conversation if there are messages
        guard let conv = conversation, !messages.isEmpty else {
            dismiss()
            return
        }
        
        // If there are at least 2 exchanges (user + assistant), generate a summary for future context
        let hasSubstantialContent = messages.count >= 2
        
        // Build conversation with current messages
        let updatedConversation = ReadingConversation(
            id: conv.id,
            userId: conv.userId,
            timeframe: conv.timeframe,
            readingContent: conv.readingContent,
            readingDate: conv.readingDate,
            messages: messages,
            createdAt: conv.createdAt,
            updatedAt: Date(),
            elementTitle: conv.elementTitle,
            summary: conv.summary,
            isClosed: conv.isClosed
        )
        
        Task {
            do {
                if hasSubstantialContent && conv.summary == nil {
                    // Generate summary in the background for future readings
                    let summary = try await AIReadingService.shared.summarizeConversation(
                        conversation: updatedConversation,
                        chart: chart,
                        profile: profile
                    )
                    
                    // Save as UserContext so future readings/chats can access this insight
                    let contextEntry = UserContext(
                        id: UUID(),
                        userId: profile.id,
                        promptType: .readingConversation,
                        question: "Conversation about \(elementTitle)",
                        response: summary,
                        createdAt: Date(),
                        tags: "element"
                    )
                    
                    try await FirestoreService.shared.saveUserContext(contextEntry)
                    
                    // Save the conversation with summary
                    try await FirestoreService.shared.saveConversation(
                        updatedConversation.closed(withSummary: summary)
                    )
                    print("✅ Element conversation saved with summary")
                } else {
                    // Just save the conversation without summary (too short or already has one)
                    try await FirestoreService.shared.saveConversation(updatedConversation)
                    print("✅ Element conversation saved (no summary needed)")
                }
            } catch {
                print("❌ Failed to save element conversation: \(error)")
            }
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack {
            Button(action: { handleDismiss() }) {
                Label("Done", systemImage: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(accentColor)
            }
            
            Spacer()
            
            Text(elementTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Spacer()
            
            // Messages indicator
            Button(action: { showingMessagesSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("\(conversationManager.remainingMessages)")
                        .font(.system(size: 12, weight: .semibold))
                    if !conversationManager.canSendMessage {
                        Text("Get more")
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(conversationManager.canSendMessage ? 
                    (conversationManager.isLowOnMessages ? .orange : .white.opacity(0.6)) : 
                    accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(conversationManager.canSendMessage ? 
                            Color.white.opacity(0.08) : 
                            accentColor.opacity(0.2))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Context Card
    
    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid")
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                
                Text("UNDERSTANDING YOUR CHART")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                
                Spacer()
            }
            
            Text(elementContent.isEmpty ? "Your chart placement" : elementContent)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
                .lineLimit(6)
            
            Text("What would you like to explore?")
                .font(.custom("Georgia", size: 15))
                .foregroundColor(.white.opacity(0.8))
                .italic()
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.top, 16)
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Ask about this placement...", text: $inputText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                )
                .lineLimit(1...4)
                .focused($isInputFocused)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? accentColor : accentColor.opacity(0.3))
            }
            .disabled(!canSend)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
    }
    
    private var outOfMessagesView: some View {
        VStack(spacing: 12) {
            Text("You're out of messages")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Button(action: { showingMessagesSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Get More Messages")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(accentColor)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.4))
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        conversationManager.canSendMessage &&
        !isLoading
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty, let currentConversation = conversation else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: trimmedInput)
        messages.append(userMessage)
        
        // Clear input and record usage
        inputText = ""
        conversationManager.recordMessageSent()
        
        // Generate response
        isLoading = true
        
        Task {
            do {
                let response = try await AIReadingService.shared.continueElementConversation(
                    elementTitle: elementTitle,
                    elementContent: elementContent,
                    messages: messages,
                    userMessage: trimmedInput,
                    chart: chart,
                    profile: profile,
                    contexts: contexts
                )
                
                await MainActor.run {
                    let assistantMessage = ChatMessage(role: .assistant, content: response)
                    messages.append(assistantMessage)
                    isLoading = false
                    scrollToBottom()
                    
                    // Auto-save conversation after each exchange
                    Task {
                        await saveCurrentConversation()
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        role: .assistant,
                        content: "I'm having trouble connecting right now. Please try again in a moment."
                    )
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
    
    private func saveCurrentConversation() async {
        guard let currentConversation = conversation else { return }
        
        let updatedConversation = ReadingConversation(
            id: currentConversation.id,
            userId: currentConversation.userId,
            timeframe: currentConversation.timeframe,
            readingContent: currentConversation.readingContent,
            readingDate: currentConversation.readingDate,
            messages: messages,
            createdAt: currentConversation.createdAt,
            updatedAt: Date(),
            elementTitle: currentConversation.elementTitle,
            summary: currentConversation.summary,
            isClosed: currentConversation.isClosed
        )
        
        do {
            try await FirestoreService.shared.saveConversation(updatedConversation)
        } catch {
            print("❌ Failed to auto-save element conversation: \(error)")
        }
    }
    
    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

#Preview {
    ElementChatView(
        elementTitle: "Sun in Capricorn",
        elementContent: "Your Sun in Capricorn speaks to a deep need for achievement and structure. This placement gives you natural discipline and ambition, driving you to build something lasting in the world.",
        chart: BirthChart(
            userId: UUID(),
            chartType: "FULL_NATAL",
            metadata: ChartMetadata(
                birthDate: Date(),
                birthTimeInput: nil,
                birthPlaceInput: nil,
                latitude: nil,
                longitude: nil,
                timezone: nil,
                houseSystem: "PLACIDUS",
                nodeType: "true",
                utcDateTimeUsed: nil,
                julianDay: nil,
                assumptions: []
            ),
            angles: nil,
            houses: nil,
            planets: [],
            aspects: nil,
            evolutionaryCore: EvolutionaryCore(
                pluto: nil,
                northNode: nil,
                southNode: nil,
                moon: nil,
                sun: nil,
                risingSign: nil,
                notes: []
            )
        ),
        profile: UserProfile(
            name: "Alex",
            email: "alex@example.com",
            dateOfBirth: Date(),
            authProvider: "email"
        ),
        contexts: [],
        accentColor: Color(red: 0.6, green: 0.75, blue: 0.5)
    )
    .preferredColorScheme(.dark)
}

