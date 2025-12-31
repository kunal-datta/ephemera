//
//  UserContext.swift
//  ephemera
//
//  A time-series journal of life context entries.
//  This is append-only — we accumulate context rather than overwriting.
//  The AI uses all historical context to understand the user's evolving journey.
//
//  Think of this as a chronological record of:
//  - What was happening in their life at various points
//  - What they were struggling with or excited about
//  - How readings resonated (or didn't)
//  - Their evolving relationship with astrology
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation
import SwiftData

/// Types of journal entries / context prompts
enum ContextPromptType: String, Codable, CaseIterable {
    case onboarding = "onboarding"           // Initial "what's on your mind?" question
    case postReading = "post_reading"        // After a reading: "Did this resonate?"
    case lifeUpdate = "life_update"          // Periodic check-ins
    case challenge = "challenge"             // "What are you struggling with?"
    case aspiration = "aspiration"           // "What are you working toward?"
    case reflection = "reflection"           // General life reflection
    case journal = "journal"                 // Free-form journal entry
    case freeform = "freeform"               // User-initiated sharing (legacy)
    
    var displayName: String {
        switch self {
        case .onboarding: return "First thoughts"
        case .postReading: return "Reading reflection"
        case .lifeUpdate: return "Life update"
        case .challenge: return "Challenge"
        case .aspiration: return "Aspiration"
        case .reflection: return "Reflection"
        case .journal: return "Journal"
        case .freeform: return "Note"
        }
    }
    
    var icon: String {
        switch self {
        case .onboarding: return "sparkles"
        case .postReading: return "text.bubble"
        case .lifeUpdate: return "arrow.triangle.2.circlepath"
        case .challenge: return "cloud.rain"
        case .aspiration: return "star"
        case .reflection: return "thought.bubble"
        case .journal: return "book"
        case .freeform: return "note.text"
        }
    }
}

/// A single journal/context entry in the user's timeline
@Model
final class UserContext {
    var id: UUID
    var userId: UUID                         // Links to UserProfile
    var createdAt: Date                      // When this entry was created (immutable)
    var promptType: String                   // ContextPromptType rawValue
    var question: String                     // What we asked them (or empty for journal)
    var response: String                     // What they shared
    
    // Optional metadata for richer context
    var mood: String?                        // Optional mood tag (future: emoji or scale)
    var relatedReadingId: UUID?              // If this was in response to a specific reading
    var tags: String?                        // Comma-separated tags (future use)
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        promptType: ContextPromptType,
        question: String,
        response: String,
        createdAt: Date = Date(),
        mood: String? = nil,
        relatedReadingId: UUID? = nil,
        tags: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.promptType = promptType.rawValue
        self.question = question
        self.response = response
        self.createdAt = createdAt
        self.mood = mood
        self.relatedReadingId = relatedReadingId
        self.tags = tags
    }
    
    /// Convenience accessor for the typed prompt type
    var contextType: ContextPromptType {
        ContextPromptType(rawValue: promptType) ?? .freeform
    }
    
    /// Parsed tags array
    var tagsList: [String] {
        guard let tags = tags else { return [] }
        return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

// MARK: - Context Summary for AI

extension Array where Element == UserContext {
    /// Formats all context entries chronologically for inclusion in an AI prompt
    /// This gives the AI the full arc of the user's journey
    func formattedForPrompt() -> String {
        guard !isEmpty else { return "No additional context shared yet." }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let sortedEntries = self.sorted { $0.createdAt < $1.createdAt }
        
        var sections: [String] = []
        
        for context in sortedEntries {
            let date = dateFormatter.string(from: context.createdAt)
            let type = context.contextType.displayName
            
            var entry = "[\(date) — \(type)]"
            if !context.question.isEmpty {
                entry += "\nPrompt: \(context.question)"
            }
            entry += "\nUser shared: \(context.response)"
            
            if let mood = context.mood {
                entry += "\nMood: \(mood)"
            }
            
            sections.append(entry)
        }
        
        return sections.joined(separator: "\n\n---\n\n")
    }
    
    /// Returns only recent context (last N entries) for lighter prompts
    func recentEntries(_ count: Int = 5) -> [UserContext] {
        let sorted = self.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(count))
    }
    
    /// Groups entries by month for display
    func groupedByMonth() -> [(String, [UserContext])] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        let sorted = self.sorted { $0.createdAt > $1.createdAt }
        var groups: [String: [UserContext]] = [:]
        
        for context in sorted {
            let key = dateFormatter.string(from: context.createdAt)
            groups[key, default: []].append(context)
        }
        
        // Return sorted by date (most recent month first)
        return groups.sorted { group1, group2 in
            guard let date1 = group1.value.first?.createdAt,
                  let date2 = group2.value.first?.createdAt else { return false }
            return date1 > date2
        }
    }
}
