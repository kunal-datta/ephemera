//
//  TimeframeReadingCardsView.swift
//  ephemera
//
//  A swipeable card view displaying readings for different timeframes
//  (day, week, month, year) with transit-specific content.
//
//  Created by Kunal_Datta on 06/01/26.
//

import SwiftUI

// MARK: - Compact Reading Card (for HomeView)

/// A more compact version of the reading cards for the home screen
/// Data to pass to chat view
struct ChatPresentationData: Identifiable {
    let id = UUID()
    let timeframe: ReadingTimeframe
    let reading: String
    let readingDate: String  // The date when this reading was generated (yyyy-MM-dd)
    var existingConversation: ReadingConversation? = nil
}

struct CompactTimeframeReadingView: View {
    let chart: BirthChart
    let profile: UserProfile
    let contexts: [UserContext]
    
    @State private var currentIndex: Int = 0
    @State private var readings: [ReadingTimeframe: String] = [:]
    @State private var readingDates: [ReadingTimeframe: String] = [:]  // Tracks when each reading was generated
    @State private var loadingStates: [ReadingTimeframe: Bool] = [:]
    @State private var errorStates: [ReadingTimeframe: String?] = [:]
    @State private var chatPresentation: ChatPresentationData? = nil
    @State private var isLoadingConversation: Bool = false
    
    private let timeframes = ReadingTimeframe.allCases
    
    private var currentTimeframe: ReadingTimeframe {
        timeframes[currentIndex]
    }
    
    private var currentReading: String? {
        readings[currentTimeframe]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Page indicators at top (pill tabs)
            pageIndicators
                .padding(.bottom, 12)
            
            // Current card - just show one at a time, animate changes
            CompactReadingCard(
                timeframe: currentTimeframe,
                reading: readings[currentTimeframe],
                isLoading: loadingStates[currentTimeframe] ?? false || isLoadingConversation,
                error: errorStates[currentTimeframe] ?? nil,
                onRetry: { loadReading(for: currentTimeframe, forceRefresh: true) },
                onChat: {
                    if let reading = currentReading {
                        openChatForTimeframe(currentTimeframe, reading: reading)
                    }
                }
            )
            .id(currentIndex) // Force view recreation on index change
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        
                        if horizontalAmount < -50 && currentIndex < timeframes.count - 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentIndex += 1
                            }
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                        } else if horizontalAmount > 50 && currentIndex > 0 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentIndex -= 1
                            }
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                        }
                    }
            )
        }
        .onAppear {
            loadAllReadings()
        }
        .fullScreenCover(item: $chatPresentation) { data in
            NavigationStack {
                ReadingChatView(
                    timeframe: data.timeframe,
                    readingContent: data.reading,
                    chart: chart,
                    profile: profile,
                    contexts: contexts,
                    existingConversation: data.existingConversation,
                    readingDate: data.readingDate
                )
                .navigationBarHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
    
    // MARK: - Chat Opening Logic
    
    /// Opens chat for a timeframe, checking for existing open conversations first
    /// The conversation is tied to the reading's generation date, not just today
    private func openChatForTimeframe(_ timeframe: ReadingTimeframe, reading: String) {
        isLoadingConversation = true
        
        // Use the reading's cached date, falling back to today if not found
        let readingDate = readingDates[timeframe] ?? DateUtility.today
        
        print("🔍 Looking for existing conversation: timeframe=\(timeframe.rawValue), date=\(readingDate)")
        
        Task {
            do {
                // Check if there's an existing open conversation for this reading
                // We match by timeframe AND the reading's generation date
                let existingConversation = try await FirestoreService.shared.fetchOpenConversation(
                    timeframe: timeframe,
                    date: readingDate
                )
                
                if let existing = existingConversation {
                    print("✅ Found existing conversation with \(existing.messages.count) messages")
                } else {
                    print("📝 No existing conversation found, will create new one")
                }
                
                await MainActor.run {
                    isLoadingConversation = false
                    chatPresentation = ChatPresentationData(
                        timeframe: timeframe,
                        reading: reading,
                        readingDate: readingDate,
                        existingConversation: existingConversation
                    )
                }
            } catch {
                print("❌ Failed to check for existing conversation: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingConversation = false
                    // Open without existing conversation on error
                    chatPresentation = ChatPresentationData(
                        timeframe: timeframe,
                        reading: reading,
                        readingDate: readingDate
                    )
                }
            }
        }
    }
    
    private var pageIndicators: some View {
        HStack(spacing: 6) {
            ForEach(Array(timeframes.enumerated()), id: \.element) { index, timeframe in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentIndex = index
                    }
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: timeframe.icon)
                            .font(.system(size: 12))
                        
                        if index == currentIndex {
                            Text(timeframe.displayTitle)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundColor(index == currentIndex 
                        ? indicatorColor(for: timeframe)
                        : Color.white.opacity(0.35))
                    .padding(.horizontal, index == currentIndex ? 12 : 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(index == currentIndex 
                                ? indicatorColor(for: timeframe).opacity(0.15)
                                : Color.clear)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func indicatorColor(for timeframe: ReadingTimeframe) -> Color {
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
    
    // MARK: - Loading Logic
    
    private func loadAllReadings() {
        for timeframe in timeframes {
            loadReading(for: timeframe)
        }
    }
    
    private func loadReading(for timeframe: ReadingTimeframe, forceRefresh: Bool = false) {
        // Check cache first
        if !forceRefresh, let cached = loadCachedReading(for: timeframe), cached.isValid {
            readings[timeframe] = cached.reading
            readingDates[timeframe] = cached.date  // Track the cached reading's date
            return
        }
        
        // Generate new reading
        loadingStates[timeframe] = true
        errorStates[timeframe] = nil
        
        Task {
            do {
                let reading = try await AIReadingService.shared.generateTimeframeReading(
                    timeframe: timeframe,
                    chart: chart,
                    profile: profile,
                    contexts: contexts
                )
                
                await MainActor.run {
                    let todayString = CachedTimeframeReading.dateFormatter.string(from: Date())
                    readings[timeframe] = reading
                    readingDates[timeframe] = todayString  // New reading is dated today
                    loadingStates[timeframe] = false
                    saveCachedReading(reading, for: timeframe)
                }
            } catch {
                await MainActor.run {
                    errorStates[timeframe] = error.localizedDescription
                    loadingStates[timeframe] = false
                }
            }
        }
    }
    
    private func loadCachedReading(for timeframe: ReadingTimeframe) -> CachedTimeframeReading? {
        guard let data = UserDefaults.standard.data(forKey: timeframe.cacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedTimeframeReading.self, from: data)
    }
    
    private func saveCachedReading(_ reading: String, for timeframe: ReadingTimeframe) {
        let todayString = CachedTimeframeReading.dateFormatter.string(from: Date())
        let cached = CachedTimeframeReading(reading: reading, date: todayString, timeframe: timeframe)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: timeframe.cacheKey)
        }
    }
}

// MARK: - Compact Reading Card

struct CompactReadingCard: View {
    let timeframe: ReadingTimeframe
    let reading: String?
    let isLoading: Bool
    let error: String?
    let onRetry: () -> Void
    let onChat: () -> Void
    
    @StateObject private var conversationManager = ConversationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: timeframe.icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                
                Text(timeframe.headerTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .tracking(1.5)
                
                Spacer()
                
                // Date range
                Text(timeframe.dateRangeDescription())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            
            // Content
            if isLoading {
                loadingView
            } else if let reading = reading {
                Text(reading)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.8))
                    .lineSpacing(6)
            } else if error != nil {
                errorView
            } else {
                placeholderView
            }
            
            // Footer: Chat button + Swipe hint
            HStack {
                // Chat button (only show when reading is available)
                if reading != nil {
                    Button(action: onChat) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 11))
                            Text("Explore this")
                                .font(.system(size: 11, weight: .medium))
                            if conversationManager.remainingMessages > 0 {
                                Text("(\(conversationManager.remainingMessages))")
                                    .font(.system(size: 10))
                                    .foregroundColor(iconColor.opacity(0.6))
                            }
                        }
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(iconColor.opacity(0.12))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!conversationManager.canSendMessage)
                    .opacity(conversationManager.canSendMessage ? 1 : 0.5)
                }
                
                Spacer()
                
                // Swipe hint
                HStack(spacing: 4) {
                    Text("Swipe for more")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.25))
                    Image(systemName: "chevron.left.chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(Color.white.opacity(0.2))
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    borderColor.opacity(0.3),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var iconColor: Color {
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
    
    private var borderColor: Color {
        iconColor
    }
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Reading the stars...")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }
    
    private var errorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unable to load reading")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.5))
            
            Button(action: onRetry) {
                Text("Try again")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(iconColor)
            }
        }
    }
    
    private var placeholderView: some View {
        Text("Your \(timeframe.displayTitle.lowercased()) guidance is on its way...")
            .font(.system(size: 14))
            .foregroundColor(Color.white.opacity(0.45))
            .italic()
    }
}

#Preview {
    ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.09)
            .ignoresSafeArea()
        
        ScrollView {
            VStack {
                // Preview with mock data
                CompactReadingCard(
                    timeframe: .day,
                    reading: "The Moon in your sign today brings heightened emotional awareness. You may find yourself more sensitive to the energies around you, picking up on subtle shifts in your environment and relationships. This is an excellent day for introspection and creative work.",
                    isLoading: false,
                    error: nil,
                    onRetry: {},
                    onChat: {}
                )
                .padding(.horizontal, 20)
                
                CompactReadingCard(
                    timeframe: .month,
                    reading: "January 2026 arrives like a breath of fresh air, a clarity emerging from the depths. With your Sagittarian Sun, Moon, Mars and Mercury all residing in your first house, you're used to embodying the energy of initiation, always ready to begin something new.",
                    isLoading: false,
                    error: nil,
                    onRetry: {},
                    onChat: {}
                )
                .padding(.horizontal, 20)
            }
        }
    }
    .preferredColorScheme(.dark)
}
