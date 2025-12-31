//
//  UserContext.swift
//  ephemera
//
//  Stores life context entries over time.
//  This is append-only — we accumulate context rather than overwriting.
//  The AI uses all historical context to understand the user's journey.
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation
import SwiftData

/// Types of context prompts we ask the user
enum ContextPromptType: String, Codable {
    case onboarding = "onboarding"           // Initial "what's on your mind?" question
    case postReading = "post_reading"        // After a reading: "Did this resonate?"
    case lifeUpdate = "life_update"          // Periodic check-ins
    case challenge = "challenge"             // "What are you struggling with?"
    case aspiration = "aspiration"           // "What are you working toward?"
    case freeform = "freeform"               // User-initiated sharing
}

@Model
final class UserContext {
    var id: UUID
    var userId: UUID                         // Links to UserProfile
    var createdAt: Date
    var promptType: String                   // ContextPromptType rawValue
    var question: String                     // What we asked them
    var response: String                     // What they shared
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        promptType: ContextPromptType,
        question: String,
        response: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.promptType = promptType.rawValue
        self.question = question
        self.response = response
        self.createdAt = createdAt
    }
    
    /// Convenience accessor for the typed prompt type
    var contextType: ContextPromptType {
        ContextPromptType(rawValue: promptType) ?? .freeform
    }
}

// MARK: - Context Summary for AI

extension Array where Element == UserContext {
    /// Formats all context entries for inclusion in an AI prompt
    func formattedForPrompt() -> String {
        guard !isEmpty else { return "No additional context shared yet." }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        return self
            .sorted { $0.createdAt < $1.createdAt }
            .map { context in
                let date = dateFormatter.string(from: context.createdAt)
                return """
                [\(date)] \(context.question)
                User's response: \(context.response)
                """
            }
            .joined(separator: "\n\n")
    }
}

