//
//  JournalEntryView.swift
//  ephemera
//
//  A journal entry flow with two multiple choice questions (multi-select)
//  and a free-form text field for additional context.
//
//  Created by Kunal_Datta on 31/12/25.
//

import SwiftUI
import SwiftData

// MARK: - Journal Question Options

enum MoodOption: String, CaseIterable, Identifiable {
    case grounded = "Grounded"
    case anxious = "Anxious"
    case hopeful = "Hopeful"
    case uncertain = "Uncertain"
    case energized = "Energized"
    case reflective = "Reflective"
    case overwhelmed = "Overwhelmed"
    case peaceful = "Peaceful"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .grounded: return "leaf"
        case .anxious: return "wind"
        case .hopeful: return "sparkle"
        case .uncertain: return "cloud.fog"
        case .energized: return "bolt"
        case .reflective: return "moon.stars"
        case .overwhelmed: return "water.waves"
        case .peaceful: return "cloud"
        }
    }
    
    var color: Color {
        switch self {
        case .grounded: return Color(red: 0.45, green: 0.65, blue: 0.45)
        case .anxious: return Color(red: 0.7, green: 0.55, blue: 0.65)
        case .hopeful: return Color(red: 0.85, green: 0.75, blue: 0.45)
        case .uncertain: return Color(red: 0.55, green: 0.55, blue: 0.6)
        case .energized: return Color(red: 0.85, green: 0.6, blue: 0.35)
        case .reflective: return Color(red: 0.55, green: 0.5, blue: 0.7)
        case .overwhelmed: return Color(red: 0.45, green: 0.6, blue: 0.75)
        case .peaceful: return Color(red: 0.6, green: 0.7, blue: 0.75)
        }
    }
}

enum LifeAreaOption: String, CaseIterable, Identifiable {
    case relationships = "Relationships"
    case career = "Career"
    case health = "Health"
    case creativity = "Creativity"
    case spirituality = "Spirituality"
    case finances = "Finances"
    case family = "Family"
    case selfGrowth = "Growth"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .relationships: return "heart"
        case .career: return "target"
        case .health: return "leaf"
        case .creativity: return "paintbrush"
        case .spirituality: return "sparkles"
        case .finances: return "chart.line.uptrend.xyaxis"
        case .family: return "house"
        case .selfGrowth: return "arrow.up.forward"
        }
    }
}

// MARK: - Journal Entry View

struct JournalEntryView: View {
    let profile: UserProfile
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var currentStep = 0
    @State private var selectedMoods: Set<MoodOption> = []
    @State private var selectedLifeAreas: Set<LifeAreaOption> = []
    @State private var additionalThoughts = ""
    @State private var isSaving = false
    @State private var showInsightScreen = false
    @State private var generatedInsight: String?
    @State private var isLoadingInsight = false
    @State private var savedContext: UserContext?
    
    @Query private var birthCharts: [BirthChart]
    @Query private var allContexts: [UserContext]
    
    private var currentChart: BirthChart? {
        birthCharts.first
    }
    
    private var userContexts: [UserContext] {
        allContexts.filter { $0.userId == profile.id && $0.promptType == ContextPromptType.journal.rawValue }
    }
    
    private let totalSteps = 3
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.04, blue: 0.07)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Progress indicator
                progressIndicator
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                
                // Content
                TabView(selection: $currentStep) {
                    moodSelectionStep
                        .tag(0)
                    
                    lifeAreaStep
                        .tag(1)
                    
                    additionalThoughtsStep
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)
            }
            
            // Insight screen overlay
            if showInsightScreen {
                insightScreen
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.06))
                    )
            }
            
            Spacer()
            
            Text(formattedDate)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
            
            Spacer()
            
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentStep
                          ? Color.white.opacity(0.9)
                          : Color.white.opacity(0.15))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
        .padding(.horizontal, 60)
    }
    
    // MARK: - Step 1: Mood Selection
    
    private var moodSelectionStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("How are you feeling?")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(.white)
                    
                    Text("Select all that apply")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.top, 8)
                
                // Mood chips
                FlowLayout(spacing: 10) {
                    ForEach(MoodOption.allCases) { mood in
                        MoodChip(
                            mood: mood,
                            isSelected: selectedMoods.contains(mood),
                            action: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if selectedMoods.contains(mood) {
                                        selectedMoods.remove(mood)
                                    } else {
                                        selectedMoods.insert(mood)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 2: Life Area
    
    private var lifeAreaStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("What's on your mind?")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(.white)
                    
                    Text("Select all that apply")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.top, 8)
                
                // Life area chips
                FlowLayout(spacing: 10) {
                    ForEach(LifeAreaOption.allCases) { area in
                        AreaChip(
                            area: area,
                            isSelected: selectedLifeAreas.contains(area),
                            action: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if selectedLifeAreas.contains(area) {
                                        selectedLifeAreas.remove(area)
                                    } else {
                                        selectedLifeAreas.insert(area)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 3: Additional Thoughts
    
    private var additionalThoughtsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Anything else?")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(.white)
                    
                    Text("Optional — write freely")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.top, 8)
                
                // Text editor
                ZStack(alignment: .topLeading) {
                    if additionalThoughts.isEmpty {
                        Text("What's happening in your life right now?")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white.opacity(0.25))
                            .padding(.horizontal, 18)
                            .padding(.top, 18)
                    }
                    
                    TextEditor(text: $additionalThoughts)
                        .font(.system(size: 16))
                        .foregroundColor(Color.white.opacity(0.85))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                }
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                
                // Summary
                if !selectedMoods.isEmpty || !selectedLifeAreas.isEmpty {
                    summarySection
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !selectedMoods.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(selectedMoods), id: \.self) { mood in
                        Image(systemName: mood.symbol)
                            .font(.system(size: 16))
                            .foregroundColor(mood.color)
                    }
                }
            }
            
            if !selectedLifeAreas.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(selectedLifeAreas), id: \.self) { area in
                        HStack(spacing: 6) {
                            Image(systemName: area.symbol)
                                .font(.system(size: 11))
                            Text(area.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        currentStep -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }
            
            Button(action: {
                if currentStep < totalSteps - 1 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        currentStep += 1
                    }
                } else {
                    saveEntry()
                }
            }) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.04, green: 0.04, blue: 0.07)))
                            .scaleEffect(0.8)
                    } else {
                        Text(currentStep < totalSteps - 1 ? "Continue" : "Save")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(Color(red: 0.04, green: 0.04, blue: 0.07))
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(canProceed ? Color.white : Color.white.opacity(0.2))
                )
            }
            .disabled(!canProceed || isSaving)
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !selectedMoods.isEmpty
        case 1: return !selectedLifeAreas.isEmpty
        case 2: return true
        default: return false
        }
    }
    
    // MARK: - Insight Screen
    
    private var insightScreen: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.04, blue: 0.07)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Content
                VStack(spacing: 32) {
                    // Success indicator
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color(red: 0.45, green: 0.6, blue: 0.5).opacity(0.3), lineWidth: 1)
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(Color(red: 0.45, green: 0.6, blue: 0.5))
                        }
                        
                        Text("Entry saved")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    
                    // Insight
                    VStack(spacing: 20) {
                        if isLoadingInsight {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                
                                Text("Reflecting on your entry...")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if let insight = generatedInsight {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.8))
                                    
                                    Text("Insight")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.4))
                                        .tracking(1)
                                }
                                
                                Text(insight)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.85))
                                    .lineSpacing(6)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        } else if userContexts.count < 2 {
                            Text("Add more entries to unlock personalized insights")
                                .font(.system(size: 15))
                                .foregroundColor(Color.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                Spacer()
                
                // Continue button
                Button(action: {
                    onComplete()
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.04, green: 0.04, blue: 0.07))
                        .frame(height: 52)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 26)
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Save Entry
    
    private func saveEntry() {
        guard !selectedMoods.isEmpty, !selectedLifeAreas.isEmpty else { return }
        
        isSaving = true
        
        // Build formatted strings
        let moodStrings = selectedMoods.map { $0.rawValue }
        let areaStrings = selectedLifeAreas.map { $0.rawValue }
        
        // Build the response combining all inputs
        var response = "Moods: \(moodStrings.joined(separator: ", ")). Focus areas: \(areaStrings.joined(separator: ", "))."
        if !additionalThoughts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            response += " Additional thoughts: \(additionalThoughts.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        
        // Store primary mood (first selected) and all areas as tags
        let primaryMood = selectedMoods.first?.rawValue ?? ""
        let allTags = areaStrings.joined(separator: ", ")
        
        // Create the context entry
        let context = UserContext(
            userId: profile.id,
            promptType: .journal,
            question: "How are you feeling? What's on your mind?",
            response: response,
            mood: primaryMood,
            tags: allTags
        )
        
        // Save to SwiftData
        modelContext.insert(context)
        
        // Force save the context
        do {
            try modelContext.save()
            print("✅ Journal entry saved to SwiftData")
        } catch {
            print("❌ Failed to save to SwiftData: \(error)")
        }
        
        savedContext = context
        
        // Save to Firestore and show insight screen
        Task {
            // Save to Firestore
            do {
                try await FirestoreService.shared.saveUserContext(context)
                print("✅ Journal entry saved to Firestore")
            } catch {
                print("❌ Failed to save to Firestore: \(error)")
            }
            
            // Show insight screen
            await MainActor.run {
                isSaving = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    showInsightScreen = true
                }
                
                // Start loading insight if we have enough entries and a chart
                if userContexts.count >= 1, let chart = currentChart {
                    isLoadingInsight = true
                    generateInsight(chart: chart, newContext: context)
                }
            }
        }
    }
    
    private func generateInsight(chart: BirthChart, newContext: UserContext) {
        Task {
            do {
                // Include the new context in the list
                var allEntries = userContexts
                allEntries.insert(newContext, at: 0)
                
                let insight = try await AIReadingService.shared.generateJournalInsight(
                    chart: chart,
                    profile: profile,
                    journalEntries: allEntries
                )
                
                await MainActor.run {
                    generatedInsight = insight
                    isLoadingInsight = false
                }
            } catch {
                await MainActor.run {
                    isLoadingInsight = false
                }
                print("❌ Failed to generate insight: \(error)")
            }
        }
    }
}

// MARK: - Mood Chip

struct MoodChip: View {
    let mood: MoodOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: mood.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? mood.color : Color.white.opacity(0.5))
                
                Text(mood.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected 
                          ? mood.color.opacity(0.15)
                          : Color.white.opacity(0.04))
                    .overlay(
                        Capsule()
                            .stroke(isSelected 
                                    ? mood.color.opacity(0.4)
                                    : Color.white.opacity(0.08), 
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Area Chip

struct AreaChip: View {
    let area: LifeAreaOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: area.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.5))
                
                Text(area.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected 
                          ? Color.white.opacity(0.15) 
                          : Color.white.opacity(0.04))
                    .overlay(
                        Capsule()
                            .stroke(isSelected 
                                    ? Color.white.opacity(0.3) 
                                    : Color.white.opacity(0.08), 
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x - spacing)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Preview

#Preview {
    JournalEntryView(
        profile: UserProfile(
            name: "Test User",
            email: "test@example.com",
            dateOfBirth: Date(),
            authProvider: "email"
        ),
        onComplete: {}
    )
}
