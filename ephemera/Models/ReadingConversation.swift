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
import SwiftUI

// MARK: - Chat Context

/// Defines what triggered the chat conversation
enum ChatContext: Codable, Equatable {
    /// Chat from a timeframe reading (day, week, month, year)
    case timeframeReading(timeframe: ReadingTimeframe)
    
    /// Chat from the natal chart reading view
    case natalReading
    
    /// Chat from a specific chart element (planet, aspect, etc.)
    case chartElement(elementDescription: String)
    
    /// Chat about the entire birth chart
    case birthChart
    
    var displayTitle: String {
        switch self {
        case .timeframeReading(let timeframe):
            return "Your \(timeframe.displayTitle)"
        case .natalReading:
            return "Your Reading"
        case .chartElement(let description):
            return description
        case .birthChart:
            return "Your Chart"
        }
    }
    
    var icon: String {
        switch self {
        case .timeframeReading(let timeframe):
            return timeframe.icon
        case .natalReading:
            return "sparkles"
        case .chartElement:
            return "circle.hexagongrid"
        case .birthChart:
            return "circle.hexagongrid.fill"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .timeframeReading(let timeframe):
            switch timeframe {
            case .day: return Color(red: 0.95, green: 0.75, blue: 0.4)
            case .week: return Color(red: 0.5, green: 0.7, blue: 0.9)
            case .month: return Color(red: 0.7, green: 0.6, blue: 0.85)
            case .year: return Color(red: 0.9, green: 0.6, blue: 0.7)
            }
        case .natalReading:
            return Color(red: 0.7, green: 0.65, blue: 0.8)
        case .chartElement:
            return Color(red: 0.6, green: 0.7, blue: 0.85)
        case .birthChart:
            return Color(red: 0.65, green: 0.55, blue: 0.8)
        }
    }
    
    /// A unique key for caching/storing conversations by context
    var contextKey: String {
        switch self {
        case .timeframeReading(let timeframe):
            return "timeframe_\(timeframe.rawValue)"
        case .natalReading:
            return "natal_reading"
        case .chartElement(let description):
            // Sanitize description for use as key
            return "element_\(description.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .birthChart:
            return "birth_chart"
        }
    }
}

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

/// A conversation anchored to a specific reading or chart element
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
    
    /// For element-based chats (e.g., "Sun in Capricorn", "Your Birth Chart")
    /// When set, this indicates an element chat rather than a timeframe reading chat
    var elementTitle: String?
    
    /// Summary generated after conversation ends (for context in future readings)
    var summary: String?
    
    /// Whether the conversation has been summarized and closed
    var isClosed: Bool
    
    /// Whether this is an element-based conversation
    var isElementChat: Bool {
        elementTitle != nil
    }
    
    /// Display title for the conversation
    var displayTitle: String {
        if let element = elementTitle {
            return element
        }
        return "\(timeframe.displayTitle) Reading"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        timeframe: ReadingTimeframe,
        readingContent: String,
        readingDate: String,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        elementTitle: String? = nil,
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
        self.elementTitle = elementTitle
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
            elementTitle: elementTitle,
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
            elementTitle: elementTitle,
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
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - timeframe: The timeframe of the reading
    ///   - readingContent: The content of the reading
    ///   - readingDate: The date the reading was generated (defaults to today)
    func startConversation(
        userId: UUID,
        timeframe: ReadingTimeframe,
        readingContent: String,
        readingDate: String = DateUtility.today
    ) -> ReadingConversation {
        let conversation = ReadingConversation(
            userId: userId,
            timeframe: timeframe,
            readingContent: readingContent,
            readingDate: readingDate
        )
        activeConversation = conversation
        return conversation
    }
}

