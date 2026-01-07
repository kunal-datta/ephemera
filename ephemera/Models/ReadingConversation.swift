//
//  ReadingConversation.swift
//  ephemera
//
//  Models for chat conversations that stem from readings.
//  Conversations are anchored to a specific reading and timeframe,
//  providing focused, contextual dialogue with the user's chart.
//
//  Created by Kunal_Datta on 06/01/26.
//

import Foundation

// MARK: - Chat Message

/// A single message in a reading conversation
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    
    enum Role: String, Codable {
        case user
        case assistant
    }
    
    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Reading Conversation

/// A conversation anchored to a specific reading
/// Stored in Firestore under users/{userId}/conversations/{conversationId}
struct ReadingConversation: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let timeframe: ReadingTimeframe
    let readingContent: String           // The reading that sparked this conversation
    let readingDate: String              // Date of the reading (yyyy-MM-dd)
    let messages: [ChatMessage]
    let createdAt: Date
    let updatedAt: Date
    
    /// Summary generated after conversation ends (for context in future readings)
    var summary: String?
    
    /// Whether the conversation has been summarized and closed
    var isClosed: Bool
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        timeframe: ReadingTimeframe,
        readingContent: String,
        readingDate: String,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        summary: String? = nil,
        isClosed: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.timeframe = timeframe
        self.readingContent = readingContent
        self.readingDate = readingDate
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.summary = summary
        self.isClosed = isClosed
    }
    
    /// Creates a new conversation with an added message
    func adding(message: ChatMessage) -> ReadingConversation {
        ReadingConversation(
            id: id,
            userId: userId,
            timeframe: timeframe,
            readingContent: readingContent,
            readingDate: readingDate,
            messages: messages + [message],
            createdAt: createdAt,
            updatedAt: Date(),
            summary: summary,
            isClosed: isClosed
        )
    }
    
    /// Creates a closed version of this conversation with a summary
    func closed(withSummary summary: String) -> ReadingConversation {
        ReadingConversation(
            id: id,
            userId: userId,
            timeframe: timeframe,
            readingContent: readingContent,
            readingDate: readingDate,
            messages: messages,
            createdAt: createdAt,
            updatedAt: Date(),
            summary: summary,
            isClosed: true
        )
    }
    
    /// Number of user messages (for rate limiting)
    var userMessageCount: Int {
        messages.filter { $0.role == .user }.count
    }
    
    /// Formats messages for inclusion in AI prompt
    func formattedForPrompt() -> String {
        guard !messages.isEmpty else { return "No messages yet." }
        
        return messages.map { message in
            let role = message.role == .user ? "User" : "Astrologer"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
    }
}

// MARK: - Messages System

/// Message packages available for purchase
enum MessagePackage: CaseIterable, Identifiable {
    case small   // 10 messages
    case medium  // 30 messages
    case large   // 100 messages
    
    var id: String { title }
    
    var messageCount: Int {
        switch self {
        case .small: return 10
        case .medium: return 30
        case .large: return 100
        }
    }
    
    var title: String {
        switch self {
        case .small: return "10 Messages"
        case .medium: return "30 Messages"
        case .large: return "100 Messages"
        }
    }
    
    var price: String {
        switch self {
        case .small: return "$2.99"
        case .medium: return "$6.99"
        case .large: return "$14.99"
        }
    }
    
    var description: String {
        switch self {
        case .small: return "Perfect for a quick exploration"
        case .medium: return "Great for deeper conversations"
        case .large: return "Best value for regular users"
        }
    }
}

/// Tracks user's message balance
struct MessageBalance: Codable {
    var messages: Int
    var totalPurchased: Int  // Track lifetime purchases for analytics
    var lastUpdated: Date
    
    static var initial: MessageBalance {
        MessageBalance(messages: 10, totalPurchased: 0, lastUpdated: Date())
    }
}

// MARK: - Date Formatter (for conversation dates)

enum DateUtility {
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    static var today: String {
        dateFormatter.string(from: Date())
    }
}

// MARK: - Conversation Manager

/// Manages conversation state and message balance
@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    /// Starting messages for new users
    static let initialMessages = 10
    
    @Published var messageBalance: MessageBalance
    @Published var activeConversation: ReadingConversation?
    
    private let balanceKey = "userMessageBalance"
    
    private init() {
        // Load or create message balance
        if let data = UserDefaults.standard.data(forKey: balanceKey),
           let balance = try? JSONDecoder().decode(MessageBalance.self, from: data) {
            self.messageBalance = balance
        } else {
            self.messageBalance = MessageBalance.initial
            saveBalance()
        }
    }
    
    /// Remaining messages
    var remainingMessages: Int {
        messageBalance.messages
    }
    
    /// Whether the user can send more messages
    var canSendMessage: Bool {
        remainingMessages > 0
    }
    
    /// Whether messages are running low (show gentle reminder)
    var isLowOnMessages: Bool {
        remainingMessages > 0 && remainingMessages <= 3
    }
    
    /// Records a message sent and deducts from balance
    func recordMessageSent() {
        messageBalance.messages = max(0, messageBalance.messages - 1)
        messageBalance.lastUpdated = Date()
        saveBalance()
    }
    
    /// Adds messages (from purchase or promo)
    func addMessages(_ amount: Int) {
        messageBalance.messages += amount
        messageBalance.totalPurchased += amount
        messageBalance.lastUpdated = Date()
        saveBalance()
    }
    
    /// Purchases a message package (mocked for now)
    func purchasePackage(_ package: MessagePackage) async -> Bool {
        // TODO: Integrate real payment flow (StoreKit, Stripe, etc.)
        // For now, just add the messages immediately
        addMessages(package.messageCount)
        return true
    }
    
    private func saveBalance() {
        if let data = try? JSONEncoder().encode(messageBalance) {
            UserDefaults.standard.set(data, forKey: balanceKey)
        }
    }
    
    /// Starts a new conversation for a reading
    func startConversation(
        userId: UUID,
        timeframe: ReadingTimeframe,
        readingContent: String
    ) -> ReadingConversation {
        let conversation = ReadingConversation(
            userId: userId,
            timeframe: timeframe,
            readingContent: readingContent,
            readingDate: DateUtility.today
        )
        activeConversation = conversation
        return conversation
    }
}

