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

// MARK: - Rate Limiting

/// Tracks daily message usage for rate limiting
struct DailyMessageUsage: Codable {
    let date: String  // yyyy-MM-dd
    var messageCount: Int
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    static var today: String {
        dateFormatter.string(from: Date())
    }
    
    var isToday: Bool {
        date == Self.today
    }
}

// MARK: - Conversation Manager

/// Manages conversation state and rate limiting
@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    /// Maximum messages per day (free tier)
    static let dailyMessageLimit = 5
    
    @Published var dailyUsage: DailyMessageUsage
    @Published var activeConversation: ReadingConversation?
    
    private let usageKey = "dailyMessageUsage"
    
    private init() {
        // Load or create daily usage
        if let data = UserDefaults.standard.data(forKey: usageKey),
           let usage = try? JSONDecoder().decode(DailyMessageUsage.self, from: data),
           usage.isToday {
            self.dailyUsage = usage
        } else {
            self.dailyUsage = DailyMessageUsage(date: DailyMessageUsage.today, messageCount: 0)
        }
    }
    
    /// Remaining messages for today
    var remainingMessages: Int {
        max(0, Self.dailyMessageLimit - dailyUsage.messageCount)
    }
    
    /// Whether the user can send more messages today
    var canSendMessage: Bool {
        remainingMessages > 0
    }
    
    /// Records a message sent and persists usage
    func recordMessageSent() {
        // Reset if it's a new day
        if !dailyUsage.isToday {
            dailyUsage = DailyMessageUsage(date: DailyMessageUsage.today, messageCount: 1)
        } else {
            dailyUsage = DailyMessageUsage(date: dailyUsage.date, messageCount: dailyUsage.messageCount + 1)
        }
        
        // Persist
        if let data = try? JSONEncoder().encode(dailyUsage) {
            UserDefaults.standard.set(data, forKey: usageKey)
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
            readingDate: DailyMessageUsage.today
        )
        activeConversation = conversation
        return conversation
    }
}

