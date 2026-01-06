//
//  ReadingChatView.swift
//  ephemera
//
//  A chat interface for exploring readings with a personal astrologer.
//  Conversations are anchored to specific readings, providing focused
//  and contextual dialogue about the user's chart and current transits.
//
//  Created by Kunal_Datta on 06/01/26.
//

import SwiftUI

struct ReadingChatView: View {
    let timeframe: ReadingTimeframe
    let readingContent: String
    let chart: BirthChart
    let profile: UserProfile
    let contexts: [UserContext]
    var existingConversation: ReadingConversation? = nil
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var conversationManager = ConversationManager.shared
    
    @State private var conversation: ReadingConversation?
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showingEndConfirmation: Bool = false
    @State private var isSummarizing: Bool = false
    @FocusState private var isInputFocused: Bool
    
    // Scroll state
    @State private var scrollProxy: ScrollViewProxy?
    
    /// Whether this is viewing a closed conversation (read-only mode)
    private var isReadOnly: Bool {
        existingConversation?.isClosed == true
    }
    
    private var accentColor: Color {
        switch timeframe {
        case .day:
            return Color(red: 0.95, green: 0.75, blue: 0.4)
        case .week:
            return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .month:
            return Color(red: 0.7, green: 0.6, blue: 0.85)
        case .year:
            return Color(red: 0.9, green: 0.6, blue: 0.7)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - keep it flat, no nested HStack/VStack
            HStack {
                Button(action: { dismiss() }) {
                    Label("Done", systemImage: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(accentColor)
                }
                
                Spacer()
                
                Text("Exploring Your \(timeframe.displayTitle)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Text("\(conversationManager.remainingMessages) left")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Reading context card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: timeframe.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(accentColor)
                                
                                Text(timeframe.headerTitle)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .tracking(1)
                                
                                Spacer()
                                
                                Text(timeframe.dateRangeDescription())
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            
                            Text(readingContent.isEmpty ? "No reading content available" : readingContent)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(4)
                            
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
                        
                        // Messages
                        if let conversation = conversation {
                            ForEach(conversation.messages) { message in
                                MessageBubble(message: message, accentColor: accentColor)
                                    .id(message.id)
                            }
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
                .onChange(of: conversation?.messages.count) { _, _ in scrollToBottom() }
            }
            .frame(maxWidth: .infinity)
            
            // Input area
            HStack(spacing: 12) {
                TextField("Ask about your reading...", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                    )
                    .lineLimit(1...4)
                
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
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.04, green: 0.04, blue: 0.09))
        .onAppear { startConversation() }
        .alert("End Conversation?", isPresented: $showingEndConfirmation) {
            Button("Keep Chatting", role: .cancel) { }
            Button("End & Save", role: .destructive) { endConversation() }
        } message: {
            Text("This will save a summary of your conversation to inform future readings.")
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack {
            Button(action: {
                if isReadOnly || (conversation?.messages.isEmpty ?? true) {
                    dismiss()
                } else {
                    showingEndConfirmation = true
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text(isReadOnly ? "Back" : "Done")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(accentColor)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(isReadOnly ? "Past Conversation" : "Exploring Your \(timeframe.displayTitle)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                if isReadOnly {
                    Text(formattedConversationDate)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                } else {
                    Text("\(conversationManager.remainingMessages) messages remaining today")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            // Balance the back button
            Color.clear.frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
    
    private var formattedConversationDate: String {
        guard let conv = existingConversation else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: conv.createdAt)
    }
    
    // MARK: - Reading Context Card
    
    private var readingContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: timeframe.icon)
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                
                Text(timeframe.headerTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                
                Spacer()
                
                Text(timeframe.dateRangeDescription())
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
            
            Text(readingContent)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(4)
                .lineLimit(6)
            
            // Prompt
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
    }
    
    // MARK: - Input Area
    
    @ViewBuilder
    private var inputArea: some View {
        if isReadOnly {
            // Read-only footer for closed conversations
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.4))
                    
                    Text("This conversation has ended")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4))
            }
        } else {
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 12) {
                    // Text field
                    TextField("Ask about your reading...", text: $inputText, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.08))
                        )
                        .focused($isInputFocused)
                        .lineLimit(1...4)
                        .disabled(!conversationManager.canSendMessage || isLoading)
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(canSend ? accentColor : accentColor.opacity(0.3))
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.4))
            }
        }
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        conversationManager.canSendMessage &&
        !isLoading
    }
    
    // MARK: - Actions
    
    private func startConversation() {
        if let existing = existingConversation {
            // Continue existing conversation
            conversation = existing
            conversationManager.activeConversation = existing
        } else {
            // Start new conversation
            conversation = conversationManager.startConversation(
                userId: profile.id,
                timeframe: timeframe,
                readingContent: readingContent
            )
        }
    }
    
    private func sendMessage() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty, var currentConversation = conversation else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: trimmedInput)
        currentConversation = currentConversation.adding(message: userMessage)
        conversation = currentConversation
        conversationManager.activeConversation = currentConversation
        
        // Clear input and record usage
        inputText = ""
        conversationManager.recordMessageSent()
        
        // Generate response
        isLoading = true
        
        Task {
            do {
                let response = try await AIReadingService.shared.continueReadingConversation(
                    conversation: currentConversation,
                    userMessage: trimmedInput,
                    chart: chart,
                    profile: profile,
                    contexts: contexts
                )
                
                await MainActor.run {
                    let assistantMessage = ChatMessage(role: .assistant, content: response)
                    if var conv = conversation {
                        conv = conv.adding(message: assistantMessage)
                        conversation = conv
                        conversationManager.activeConversation = conv
                    }
                    isLoading = false
                    scrollToBottom()
                }
            } catch {
                await MainActor.run {
                    // Add error message as assistant response
                    let errorMessage = ChatMessage(
                        role: .assistant,
                        content: "I'm having trouble connecting right now. Please try again in a moment."
                    )
                    if var conv = conversation {
                        conv = conv.adding(message: errorMessage)
                        conversation = conv
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func endConversation() {
        guard let currentConversation = conversation, !currentConversation.messages.isEmpty else {
            dismiss()
            return
        }
        
        isSummarizing = true
        
        Task {
            do {
                // Generate summary
                let summary = try await AIReadingService.shared.summarizeConversation(
                    conversation: currentConversation,
                    chart: chart,
                    profile: profile
                )
                
                // Save as UserContext
                let contextEntry = UserContext(
                    id: UUID(),
                    userId: profile.id,
                    promptType: .readingConversation,
                    question: "Conversation about \(timeframe.rawValue)ly reading (\(currentConversation.readingDate))",
                    response: summary,
                    createdAt: Date(),
                    tags: timeframe.rawValue
                )
                
                try await FirestoreService.shared.saveUserContext(contextEntry)
                
                // Also save the full conversation
                try await FirestoreService.shared.saveConversation(
                    currentConversation.closed(withSummary: summary)
                )
                
                await MainActor.run {
                    isSummarizing = false
                    dismiss()
                }
            } catch {
                print("❌ Failed to save conversation: \(error)")
                await MainActor.run {
                    isSummarizing = false
                    dismiss()
                }
            }
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

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let accentColor: Color
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(isUser ? .white : .white.opacity(0.85))
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isUser ? accentColor.opacity(0.3) : Color.white.opacity(0.08))
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 4)
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    let color: Color
    
    @State private var animationPhase: Int = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color.opacity(animationPhase == index ? 0.8 : 0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReadingChatView(
        timeframe: .day,
        readingContent: "The Moon in your sign today brings heightened emotional awareness. You may find yourself more sensitive to the energies around you, picking up on subtle shifts in your environment and relationships. This is an excellent day for introspection and creative work. Trust what your intuition is telling you.",
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
        contexts: []
    )
    .preferredColorScheme(.dark)
}

