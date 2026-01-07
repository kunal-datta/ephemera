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

// MARK: - Credits System

/// Credit packages available for purchase
enum CreditPackage: CaseIterable, Identifiable {
    case small   // 10 credits
    case medium  // 30 credits
    case large   // 100 credits
    
    var id: String { title }
    
    var credits: Int {
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

/// Tracks user's credit balance
struct CreditBalance: Codable {
    var credits: Int
    var totalPurchased: Int  // Track lifetime purchases for analytics
    var lastUpdated: Date
    
    static var initial: CreditBalance {
        CreditBalance(credits: 10, totalPurchased: 0, lastUpdated: Date())
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

/// Manages conversation state and credits
@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    /// Starting credits for new users
    static let initialCredits = 10
    
    @Published var creditBalance: CreditBalance
    @Published var activeConversation: ReadingConversation?
    
    private let creditsKey = "userCreditBalance"
    
    private init() {
        // Load or create credit balance
        if let data = UserDefaults.standard.data(forKey: creditsKey),
           let balance = try? JSONDecoder().decode(CreditBalance.self, from: data) {
            self.creditBalance = balance
        } else {
            self.creditBalance = CreditBalance.initial
            saveBalance()
        }
    }
    
    /// Remaining messages (credits)
    var remainingMessages: Int {
        creditBalance.credits
    }
    
    /// Whether the user can send more messages
    var canSendMessage: Bool {
        remainingMessages > 0
    }
    
    /// Whether credits are running low (show gentle reminder)
    var isLowOnCredits: Bool {
        remainingMessages > 0 && remainingMessages <= 3
    }
    
    /// Records a message sent and deducts a credit
    func recordMessageSent() {
        creditBalance.credits = max(0, creditBalance.credits - 1)
        creditBalance.lastUpdated = Date()
        saveBalance()
    }
    
    /// Adds credits (from purchase or promo)
    func addCredits(_ amount: Int) {
        creditBalance.credits += amount
        creditBalance.totalPurchased += amount
        creditBalance.lastUpdated = Date()
        saveBalance()
    }
    
    /// Purchases a credit package (mocked for now)
    func purchasePackage(_ package: CreditPackage) async -> Bool {
        // TODO: Integrate real payment flow (StoreKit, Stripe, etc.)
        // For now, just add the credits immediately
        addCredits(package.credits)
        return true
    }
    
    private func saveBalance() {
        if let data = try? JSONEncoder().encode(creditBalance) {
            UserDefaults.standard.set(data, forKey: creditsKey)
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

