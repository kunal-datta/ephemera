//
//  BirthChartView.swift
//  ephemera
//
//  A beautiful visualization of the user's birth chart.
//  Displays the chart wheel, planetary placements, and key information.
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData

/// What the user tapped on for the detail sheet
enum ChartElementSelection: Identifiable {
    case planet(PlanetaryPosition)
    case bigThree(type: String, sign: ZodiacSign, planet: Planet?) // "Sun", "Moon", or "Rising"
    case aspect(ChartAspect)
    case evolutionaryPoint(title: String, position: PlanetaryPosition)
    
    var id: String {
        switch self {
        case .planet(let pos): return "planet-\(pos.planet.rawValue)"
        case .bigThree(let type, _, _): return "bigthree-\(type)"
        case .aspect(let asp): return "aspect-\(asp.id)"
        case .evolutionaryPoint(let title, _): return "evo-\(title)"
        }
    }
}

struct BirthChartView: View {
    let initialChart: BirthChart
    @Query private var profiles: [UserProfile]
    @Query private var birthCharts: [BirthChart]
    @Query private var contexts: [UserContext]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPlanet: PlanetaryPosition?
    @State private var showPlanetDetail = false
    @State private var showProfile = false
    @State private var showReading = false
    @State private var showJournalEntry = false
    @State private var shouldDismissAfterProfileUpdate = false
    @State private var selectedElement: ChartElementSelection?
    @State private var selectedTab: Int = 0 // 0 = Chart, 1 = Journal
    @State private var journalInsight: String?
    @State private var isLoadingInsight = false
    @State private var lastInsightEntryCount = 0
    
    private var currentProfile: UserProfile? {
        profiles.first
    }
    
    private var userContexts: [UserContext] {
        guard let profile = currentProfile else { return [] }
        return contexts.filter { $0.userId == profile.id }
    }
    
    private var journalContexts: [UserContext] {
        userContexts
            .filter { $0.promptType == ContextPromptType.journal.rawValue }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    // Use the latest chart from SwiftData, falling back to initial chart
    private var chart: BirthChart {
        birthCharts.first ?? initialChart
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.06, green: 0.04, blue: 0.14),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle star field
            StarFieldView()
                .opacity(0.25)
            
            VStack(spacing: 0) {
                // Segmented Control
                segmentedControl
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                // Content based on selected tab
                if selectedTab == 0 {
                    chartContent
                } else {
                    journalContent
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Your Birth Chart")
                    .font(.custom("Georgia", size: 18))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showProfile = true }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                }
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let profile = currentProfile {
                ProfileEditView(profile: profile) {
                    // Chart has been deleted inside ProfileEditView
                    // Set flag to dismiss this view when profile sheet closes
                    shouldDismissAfterProfileUpdate = true
                }
            }
        }
        .navigationDestination(isPresented: $showReading) {
            if let profile = currentProfile {
                ChartReadingView(chart: chart, profile: profile)
            }
        }
        .onChange(of: showProfile) { _, isShowing in
            // When profile view is dismissed and we need to go back to home
            if !isShowing && shouldDismissAfterProfileUpdate {
                shouldDismissAfterProfileUpdate = false
                dismiss()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedElement) { element in
            if let profile = currentProfile {
                ChartElementDetailSheet(
                    element: element,
                    chart: chart,
                    profile: profile,
                    contexts: userContexts
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showJournalEntry) {
            if let profile = currentProfile {
                JournalEntryView(profile: profile) {
                    // Entry was saved - navigate to Journal tab
                    selectedTab = 1
                }
            }
        }
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Chart", icon: "circle.hexagongrid", index: 0)
            segmentButton(title: "Journal", icon: "book", index: 1)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 24)
    }
    
    private func segmentButton(title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        
        return Button(action: {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Chart Content
    
    private var chartContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                headerSection
                
                // Journal Entry (with history link underneath)
                journalEntryButton
                
                // Chart Wheel
                chartWheelSection
                
                // Reading link (under the chart where people expect to tap)
                readingLink
                    .padding(.top, -16) // Pull it closer to chart
                
                // Big Three
                bigThreeSection
                
                // Planetary Placements
                planetaryPlacementsSection
                
                // Evolutionary Core
                evolutionaryCoreSection
                
                // Aspects (if available)
                if let aspects = chart.aspects, !aspects.isEmpty {
                    aspectsSection(aspects: aspects)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Journal Content
    
    private var journalContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Add new entry button
                journalAddEntryButton
                
                // Journal entries list
                if journalContexts.isEmpty {
                    journalEmptyState
                } else {
                    // Activity calendar
                    journalActivityCalendar
                    
                    // Stats row
                    journalStatsRow
                    
                    // Mood breakdown
                    journalMoodBreakdown
                    
                    // Mood patterns over time
                    journalMoodOverTimeChart
                    
                    // Focus areas
                    journalFocusAreas
                    
                    // Focus areas over time
                    journalFocusAreasOverTimeChart
                    
                    // AI Insight
                    journalAIInsight
                    
                    // Entries
                    LazyVStack(spacing: 12) {
                        ForEach(journalContexts, id: \.id) { entry in
                            EntryCard(entry: entry)
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .onAppear {
            if journalContexts.count >= 2 && (journalInsight == nil || lastInsightEntryCount != journalContexts.count) {
                generateJournalInsight()
            }
        }
        .onChange(of: journalContexts.count) { oldCount, newCount in
            if newCount >= 2 && newCount != lastInsightEntryCount {
                generateJournalInsight()
            }
        }
    }
    
    private var journalAddEntryButton: some View {
        Button(action: { showJournalEntry = true }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.white.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Entry")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.9))
                    
                    Text("How are you feeling today?")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var journalEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Color.white.opacity(0.25))
            
            Text("No entries yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            Text("Start journaling to track your patterns\nand get personalized insights")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private var journalStatsRow: some View {
        HStack(spacing: 12) {
            JournalStatCard(value: "\(journalContexts.count)", label: "Entries")
            JournalStatCard(value: calculateStreak(), label: "Streak")
            JournalStatCard(value: "\(uniqueJournalDays())", label: "Days")
        }
    }
    
    private func uniqueJournalDays() -> Int {
        let calendar = Calendar.current
        let uniqueDates = Set(journalContexts.map { calendar.startOfDay(for: $0.createdAt) })
        return uniqueDates.count
    }
    
    private func calculateStreak() -> String {
        guard !journalContexts.isEmpty else { return "0" }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        var datesWithEntries = Set<Date>()
        for entry in journalContexts {
            datesWithEntries.insert(calendar.startOfDay(for: entry.createdAt))
        }
        
        var streak = 0
        var checkDate: Date
        
        if datesWithEntries.contains(today) {
            checkDate = today
        } else if datesWithEntries.contains(yesterday) {
            checkDate = yesterday
        } else {
            return "0"
        }
        
        while datesWithEntries.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        return "\(streak)"
    }
    
    // MARK: - Activity Calendar
    
    private var journalActivityCalendar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Journal activity")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                
                Spacer()
                
                Text("Last 4 weeks")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            
            // Calendar grid - 8 weeks x 7 days (full width)
            ActivityCalendarGrid(
                allDays: generateActivityDays(),
                activityColorProvider: activityColor
            )
            
            // Legend
            HStack(spacing: 6) {
                Text("Less")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.3))
                
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(activityColor(for: level))
                        .frame(width: 14, height: 14)
                }
                
                Text("More")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private func generateActivityDays() -> [ActivityDayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Find what day of week today is (1 = Sunday, 7 = Saturday)
        let todayWeekday = calendar.component(.weekday, from: today)
        
        // Calculate start of this week (Sunday)
        let startOfThisWeek = calendar.date(byAdding: .day, value: -(todayWeekday - 1), to: today)!
        
        // Go back 3 more weeks (4 weeks total including current)
        let startDate = calendar.date(byAdding: .day, value: -21, to: startOfThisWeek)!
        
        var days: [ActivityDayData] = []
        
        // Generate 28 days (4 weeks)
        for dayOffset in 0..<28 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
            let count = entriesOnDate(date)
            let isFuture = date > today
            
            days.append(ActivityDayData(date: date, count: count, isFuture: isFuture))
        }
        
        return days
    }
    
    private func entriesOnDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        return journalContexts.filter { entry in
            let entryDay = calendar.startOfDay(for: entry.createdAt)
            return entryDay == startOfDay
        }.count
    }
    
    private func activityColor(for count: Int) -> Color {
        switch count {
        case 0: return Color.white.opacity(0.04)
        case 1: return Color(red: 0.4, green: 0.55, blue: 0.45).opacity(0.5)
        case 2: return Color(red: 0.4, green: 0.55, blue: 0.45).opacity(0.7)
        case 3: return Color(red: 0.4, green: 0.55, blue: 0.45).opacity(0.85)
        default: return Color(red: 0.4, green: 0.55, blue: 0.45)
        }
    }
    
    // MARK: - Mood Breakdown
    
    private var journalMoodBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mood patterns")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
            
            let moodCounts = calculateMoodCounts()
            let maxCount = moodCounts.values.max() ?? 1
            
            VStack(spacing: 10) {
                ForEach(moodCounts.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { mood, count in
                    HStack(spacing: 12) {
                        Image(systemName: moodSymbol(for: mood))
                            .font(.system(size: 14))
                            .foregroundColor(moodColor(for: mood))
                            .frame(width: 20)
                        
                        Text(mood)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.8))
                            .frame(width: 80, alignment: .leading)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(moodColor(for: mood).opacity(0.5))
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            }
                        }
                        .frame(height: 6)
                        
                        Text("\(count)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.4))
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private func calculateMoodCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in journalContexts {
            if let response = entry.response.range(of: "Moods: ") {
                let afterMoods = entry.response[response.upperBound...]
                if let periodIndex = afterMoods.firstIndex(of: ".") {
                    let moodsString = String(afterMoods[..<periodIndex])
                    let moods = moodsString.components(separatedBy: ", ")
                    for mood in moods {
                        let trimmed = mood.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            counts[trimmed, default: 0] += 1
                        }
                    }
                }
            }
        }
        return counts
    }
    
    private func moodSymbol(for mood: String) -> String {
        switch mood {
        case "Grounded": return "leaf"
        case "Anxious": return "wind"
        case "Hopeful": return "sparkle"
        case "Uncertain": return "cloud.fog"
        case "Energized": return "bolt"
        case "Reflective": return "moon.stars"
        case "Overwhelmed": return "water.waves"
        case "Peaceful": return "cloud"
        default: return "circle"
        }
    }
    
    private func moodColor(for mood: String) -> Color {
        switch mood {
        case "Grounded": return Color(red: 0.45, green: 0.65, blue: 0.45)
        case "Anxious": return Color(red: 0.7, green: 0.55, blue: 0.65)
        case "Hopeful": return Color(red: 0.85, green: 0.75, blue: 0.45)
        case "Uncertain": return Color(red: 0.55, green: 0.55, blue: 0.6)
        case "Energized": return Color(red: 0.85, green: 0.6, blue: 0.35)
        case "Reflective": return Color(red: 0.55, green: 0.5, blue: 0.7)
        case "Overwhelmed": return Color(red: 0.45, green: 0.6, blue: 0.75)
        case "Peaceful": return Color(red: 0.6, green: 0.7, blue: 0.75)
        default: return Color.white.opacity(0.5)
        }
    }
    
    // MARK: - Focus Areas Breakdown
    
    private var journalFocusAreas: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus areas")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
            
            let areaCounts = calculateLifeAreaCounts()
            
            FlowLayout(spacing: 8) {
                ForEach(areaCounts.sorted(by: { $0.value > $1.value }), id: \.key) { area, count in
                    HStack(spacing: 6) {
                        Image(systemName: areaSymbol(for: area))
                            .font(.system(size: 11))
                        
                        Text(area)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.8))
                        
                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private func calculateLifeAreaCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in journalContexts {
            if let response = entry.response.range(of: "Focus areas: ") {
                let afterAreas = entry.response[response.upperBound...]
                if let periodIndex = afterAreas.firstIndex(of: ".") {
                    let areasString = String(afterAreas[..<periodIndex])
                    let areas = areasString.components(separatedBy: ", ")
                    for area in areas {
                        let trimmed = area.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            counts[trimmed, default: 0] += 1
                        }
                    }
                }
            }
        }
        return counts
    }
    
    private func areaSymbol(for area: String) -> String {
        switch area {
        case "Relationships": return "heart"
        case "Career": return "target"
        case "Health": return "leaf"
        case "Creativity": return "paintbrush"
        case "Spirituality": return "sparkles"
        case "Finances": return "chart.line.uptrend.xyaxis"
        case "Family": return "house"
        case "Growth": return "arrow.up.forward"
        default: return "circle"
        }
    }
    
    private func areaColor(for area: String) -> Color {
        switch area {
        case "Relationships": return Color(red: 0.85, green: 0.5, blue: 0.55)
        case "Career": return Color(red: 0.55, green: 0.65, blue: 0.85)
        case "Health": return Color(red: 0.45, green: 0.7, blue: 0.5)
        case "Creativity": return Color(red: 0.85, green: 0.65, blue: 0.45)
        case "Spirituality": return Color(red: 0.7, green: 0.55, blue: 0.8)
        case "Finances": return Color(red: 0.5, green: 0.75, blue: 0.7)
        case "Family": return Color(red: 0.75, green: 0.6, blue: 0.5)
        case "Growth": return Color(red: 0.65, green: 0.75, blue: 0.55)
        default: return Color.white.opacity(0.5)
        }
    }
    
    // MARK: - Mood Patterns Over Time Chart
    
    private var journalMoodOverTimeChart: some View {
        let timeData = calculateMoodOverTime()
        let topMoods = getTopMoods(from: timeData, limit: 4)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Mood patterns over time")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
            
            if timeData.isEmpty {
                Text("Add more entries to see trends")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                MoodOverTimeChartContent(
                    timeData: timeData,
                    topMoods: topMoods,
                    moodColorProvider: moodColor,
                    formatDate: formatShortDate
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Focus Areas Over Time Chart
    
    private var journalFocusAreasOverTimeChart: some View {
        let timeData = calculateFocusAreasOverTime()
        let topAreas = getTopAreas(from: timeData, limit: 5)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Focus areas over time")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
            
            if timeData.isEmpty {
                Text("Add more entries to see trends")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                FocusAreasOverTimeChartContent(
                    timeData: timeData,
                    topAreas: topAreas,
                    areaColorProvider: areaColor,
                    formatDate: formatShortDate
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Chart Data Calculations
    
    private func calculateMoodOverTime() -> [DayMoodChartData] {
        let calendar = Calendar.current
        var dayData: [Date: [String: Int]] = [:]
        
        for entry in journalContexts {
            let day = calendar.startOfDay(for: entry.createdAt)
            if dayData[day] == nil {
                dayData[day] = [:]
            }
            
            if let response = entry.response.range(of: "Moods: ") {
                let afterMoods = entry.response[response.upperBound...]
                if let periodIndex = afterMoods.firstIndex(of: ".") {
                    let moodsString = String(afterMoods[..<periodIndex])
                    let moods = moodsString.components(separatedBy: ", ")
                    for mood in moods {
                        let trimmed = mood.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            dayData[day]![trimmed, default: 0] += 1
                        }
                    }
                }
            }
        }
        
        let sortedDays = dayData.keys.sorted()
        let limitedDays = Array(sortedDays.suffix(14))
        return limitedDays.map { DayMoodChartData(date: $0, moodCounts: dayData[$0] ?? [:]) }
    }
    
    private func calculateFocusAreasOverTime() -> [DayAreaChartData] {
        let calendar = Calendar.current
        var dayData: [Date: [String: Int]] = [:]
        
        for entry in journalContexts {
            let day = calendar.startOfDay(for: entry.createdAt)
            if dayData[day] == nil {
                dayData[day] = [:]
            }
            
            if let response = entry.response.range(of: "Focus areas: ") {
                let afterAreas = entry.response[response.upperBound...]
                if let periodIndex = afterAreas.firstIndex(of: ".") {
                    let areasString = String(afterAreas[..<periodIndex])
                    let areas = areasString.components(separatedBy: ", ")
                    for area in areas {
                        let trimmed = area.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            dayData[day]![trimmed, default: 0] += 1
                        }
                    }
                }
            }
        }
        
        let sortedDays = dayData.keys.sorted()
        let limitedDays = Array(sortedDays.suffix(14))
        return limitedDays.map { DayAreaChartData(date: $0, areaCounts: dayData[$0] ?? [:]) }
    }
    
    private func getTopMoods(from data: [DayMoodChartData], limit: Int) -> [String] {
        var totalCounts: [String: Int] = [:]
        for day in data {
            for (mood, count) in day.moodCounts {
                totalCounts[mood, default: 0] += count
            }
        }
        return Array(totalCounts.sorted { $0.value > $1.value }.prefix(limit).map { $0.key })
    }
    
    private func getTopAreas(from data: [DayAreaChartData], limit: Int) -> [String] {
        var totalCounts: [String: Int] = [:]
        for day in data {
            for (area, count) in day.areaCounts {
                totalCounts[area, default: 0] += count
            }
        }
        return Array(totalCounts.sorted { $0.value > $1.value }.prefix(limit).map { $0.key })
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    // MARK: - AI Insight Card
    
    private var journalAIInsight: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.7, green: 0.6, blue: 0.85))
                
                Text("Insight")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                
                Spacer()
                
                if isLoadingInsight {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            if isLoadingInsight {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 14)
                    }
                }
                .padding(.vertical, 8)
            } else if let insight = journalInsight {
                Text(insight)
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.8))
                    .lineSpacing(5)
            } else if journalContexts.count < 2 {
                Text("Add a few more journal entries to unlock personalized insights based on your patterns and birth chart.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
                    .italic()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.7, green: 0.6, blue: 0.85).opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.7, green: 0.6, blue: 0.85).opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // MARK: - AI Generation
    
    private func generateJournalInsight() {
        guard let chart = chart as BirthChart?, let profile = currentProfile, !isLoadingInsight else { return }
        
        isLoadingInsight = true
        let currentCount = journalContexts.count
        
        Task {
            do {
                let insight = try await AIReadingService.shared.generateJournalInsight(
                    chart: chart,
                    profile: profile,
                    journalEntries: journalContexts
                )
                
                await MainActor.run {
                    journalInsight = insight
                    lastInsightEntryCount = currentCount
                    isLoadingInsight = false
                }
            } catch {
                await MainActor.run {
                    journalInsight = "Unable to generate insight right now. Please try again later."
                    lastInsightEntryCount = currentCount
                    isLoadingInsight = false
                }
            }
        }
    }
    
    // MARK: - Reading Link (appears under chart)
    
    private var readingLink: some View {
        Button(action: { showReading = true }) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.8))
                
                Text("Get your in-depth reading for today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Journal Entry Button
    
    private var journalEntryCount: Int {
        journalContexts.count
    }
    
    private var journalEntryButton: some View {
        VStack(spacing: 0) {
            // Main journal action - minimal, text-forward
            Button(action: { showJournalEntry = true }) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How are you today?")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.white)
                        
                        Text("Add a journal entry")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                    
                    Spacer()
                    
                    // Minimal plus icon
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Journal history link (directly under journal CTA)
            if journalEntryCount > 0 {
                Button(action: { selectedTab = 1 }) {
                    HStack(spacing: 6) {
                        Text("View \(journalEntryCount) past \(journalEntryCount == 1 ? "entry" : "entries")")
                            .font(.system(size: 13))
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.top, 4)
                    .padding(.leading, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            if let metadata = chart.metadata {
                let dateFormatter: DateFormatter = {
                    let f = DateFormatter()
                    f.dateStyle = .long
                    // Use birth location timezone to display the date correctly
                    if let tzId = metadata.timezone, let tz = TimeZone(identifier: tzId) {
                        f.timeZone = tz
                    }
                    return f
                }()
                
                Text(dateFormatter.string(from: metadata.birthDate))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                    .tracking(1)
                
                if let place = metadata.birthPlaceInput {
                    Text(place)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                }
                
                // Chart type indicator
                Text(chartTypeLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.15))
                    )
                    .padding(.top, 4)
            }
        }
    }
    
    private var chartTypeLabel: String {
        switch chart.chartType {
        case "FULL_NATAL":
            return "Full Natal Chart"
        case "NOON_CHART_NO_HOUSES":
            return "Noon Chart (Time Unknown)"
        case "SIGN_BASED_NO_HOUSES":
            return "Sign-Based Chart"
        default:
            return "Placidus Houses"
        }
    }
    
    // MARK: - Chart Wheel Section
    
    private var chartWheelSection: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, 340)
            
            Button(action: { showReading = true }) {
                ZStack {
                    // Outer ring with zodiac signs
                    ChartWheelView(
                        planets: chart.planets,
                        houses: chart.houses,
                        risingSign: chart.risingSign,
                        size: size
                    )
                }
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChartWheelButtonStyle())
        }
        .frame(height: 340)
    }
    
    // MARK: - Big Three Section
    
    private var bigThreeSection: some View {
        VStack(spacing: 16) {
            Text("THE BIG THREE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
            
            HStack(spacing: 20) {
                if let sun = chart.position(for: .sun) {
                    bigThreeCard(title: "Sun", sign: sun.sign, symbol: "☉")
                        .onTapGesture {
                            selectedElement = .bigThree(type: "Sun", sign: sun.sign, planet: .sun)
                        }
                }
                
                if let moon = chart.position(for: .moon) {
                    bigThreeCard(
                        title: "Moon",
                        sign: moon.sign,
                        symbol: "☽",
                        isUncertain: moon.signUncertain
                    )
                    .onTapGesture {
                        selectedElement = .bigThree(type: "Moon", sign: moon.sign, planet: .moon)
                    }
                }
                
                if let rising = chart.risingSign {
                    bigThreeCard(title: "Rising", sign: rising, symbol: "↑")
                        .onTapGesture {
                            selectedElement = .bigThree(type: "Rising", sign: rising, planet: nil)
                        }
                } else {
                    // Placeholder for missing rising
                    bigThreePlaceholder(title: "Rising")
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    private func bigThreeCard(title: String, sign: ZodiacSign, symbol: String, isUncertain: Bool = false) -> some View {
        VStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 24))
                .foregroundColor(elementColor(for: sign.element))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                .tracking(1)
            
            Text(sign.rawValue)
                .font(.custom("Georgia", size: 15))
                .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            
            Text(sign.symbol)
                .font(.system(size: 20))
                .foregroundColor(elementColor(for: sign.element))
            
            if isUncertain {
                Text("uncertain")
                    .font(.system(size: 9))
                    .foregroundColor(Color.orange.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle()) // Makes entire area tappable
    }
    
    private func bigThreePlaceholder(title: String) -> some View {
        VStack(spacing: 8) {
            Text("?")
                .font(.system(size: 24))
                .foregroundColor(Color(red: 0.4, green: 0.38, blue: 0.35))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                .tracking(1)
            
            Text("Unknown")
                .font(.custom("Georgia", size: 15))
                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
            
            Text("–")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.4, green: 0.38, blue: 0.35))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Planetary Placements Section
    
    private var planetaryPlacementsSection: some View {
        VStack(spacing: 16) {
            Text("PLANETARY PLACEMENTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(chart.planets, id: \.planet) { position in
                    planetCard(position: position)
                        .onTapGesture {
                            selectedElement = .planet(position)
                        }
                }
            }
        }
    }
    
    private func planetCard(position: PlanetaryPosition) -> some View {
        HStack(spacing: 12) {
            // Planet symbol
            Text(position.planet.symbol)
                .font(.system(size: 22))
                .foregroundColor(elementColor(for: position.sign.element))
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(position.planet.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.85, green: 0.82, blue: 0.78))
                    
                    if position.isRetrograde {
                        Text("℞")
                            .font(.system(size: 11))
                            .foregroundColor(Color.orange.opacity(0.8))
                    }
                }
                
                HStack(spacing: 4) {
                    Text(position.sign.symbol)
                        .font(.system(size: 14))
                    Text(position.formattedDegree)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                }
                
                if let house = position.house {
                    Text("House \(house)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Evolutionary Core Section
    
    private var evolutionaryCoreSection: some View {
        VStack(spacing: 20) {
            Text("EVOLUTIONARY ASTROLOGY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .center)
            
            if let evoCore = chart.evolutionaryCore {
                VStack(spacing: 16) {
                    // Nodes row - using grid for equal sizing
                    HStack(spacing: 12) {
                        if let northNode = evoCore.northNode {
                            evolutionaryCard(
                                title: "North Node",
                                subtitle: "Soul's Direction",
                                position: northNode,
                                color: Color(red: 0.4, green: 0.7, blue: 0.5)
                            )
                            .onTapGesture {
                                selectedElement = .evolutionaryPoint(title: "North Node", position: northNode)
                            }
                        }
                        
                        if let southNode = evoCore.southNode {
                            evolutionaryCard(
                                title: "South Node",
                                subtitle: "Past Patterns",
                                position: southNode,
                                color: Color(red: 0.7, green: 0.5, blue: 0.4)
                            )
                            .onTapGesture {
                                selectedElement = .evolutionaryPoint(title: "South Node", position: southNode)
                            }
                        }
                    }
                    
                    // Pluto - centered, matching width of nodes
                    if let pluto = evoCore.pluto {
                        evolutionaryCard(
                            title: "Pluto",
                            subtitle: "Soul's Evolution",
                            position: pluto,
                            color: Color(red: 0.6, green: 0.4, blue: 0.7)
                        )
                        .onTapGesture {
                            selectedElement = .evolutionaryPoint(title: "Pluto", position: pluto)
                        }
                    }
                }
                
                // Notes
                if !evoCore.notes.isEmpty {
                            HStack(spacing: 6) {
                        ForEach(evoCore.notes, id: \.self) { note in
                                Text(note)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.52))
                            }
                        }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    }
                }
            }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.4, blue: 0.6).opacity(0.3),
                                    Color(red: 0.4, green: 0.5, blue: 0.6).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func evolutionaryCard(title: String, subtitle: String, position: PlanetaryPosition, color: Color) -> some View {
        VStack(spacing: 8) {
            // Zodiac symbol (same as chart wheel)
            Text(position.sign.symbol)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            // Title
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Sign name
            Text(position.sign.rawValue)
                .font(.custom("Georgia", size: 15))
                .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Degree
            Text(position.formattedDegree)
                .font(.system(size: 11))
                .foregroundColor(color.opacity(0.8))
                .lineLimit(1)
            
            // Subtitle
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                .italic()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Aspects Section
    
    private func aspectsSection(aspects: [ChartAspect]) -> some View {
        VStack(spacing: 16) {
            Text("MAJOR ASPECTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                ForEach(aspects.prefix(10)) { aspect in
                    aspectRow(aspect: aspect)
                        .onTapGesture {
                            selectedElement = .aspect(aspect)
                        }
                }
            }
        }
    }
    
    private func aspectRow(aspect: ChartAspect) -> some View {
        HStack(spacing: 12) {
            Text(aspect.planet1.symbol)
                .font(.system(size: 18))
                .frame(width: 28)
            
            Text(aspect.type.symbol)
                .font(.system(size: 16))
                .foregroundColor(aspectColor(for: aspect.type))
                .frame(width: 24)
            
            Text(aspect.planet2.symbol)
                .font(.system(size: 18))
                .frame(width: 28)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(aspect.type.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                
                Text(String(format: "%.1f° orb", aspect.orb))
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Helper Functions
    
    private func elementColor(for element: Element) -> Color {
        switch element {
        case .fire:
            return Color(red: 0.95, green: 0.5, blue: 0.4)
        case .earth:
            return Color(red: 0.6, green: 0.75, blue: 0.5)
        case .air:
            return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .water:
            return Color(red: 0.5, green: 0.55, blue: 0.85)
        }
    }
    
    private func aspectColor(for type: AspectType) -> Color {
        switch type {
        case .conjunction:
            return Color(red: 0.9, green: 0.8, blue: 0.4)
        case .sextile:
            return Color(red: 0.4, green: 0.7, blue: 0.9)
        case .square:
            return Color(red: 0.9, green: 0.4, blue: 0.4)
        case .trine:
            return Color(red: 0.4, green: 0.8, blue: 0.5)
        case .opposition:
            return Color(red: 0.9, green: 0.5, blue: 0.3)
        }
    }
}

// MARK: - Chart Wheel View

struct ChartWheelView: View {
    let planets: [PlanetaryPosition]
    let houses: [House]?
    let risingSign: ZodiacSign?
    let size: CGFloat
    
    private let zodiacSigns = ZodiacSign.allCases
    
    var body: some View {
        ZStack {
            // Outer zodiac ring
            outerZodiacRing
            
            // House divisions (if available)
            if houses != nil {
                houseDivisions
            }
            
            // Planet positions
            planetPositions
            
            // Center
            centerCircle
        }
        .frame(width: size, height: size)
    }
    
    private var outerZodiacRing: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.38, blue: 0.5).opacity(0.5),
                            Color(red: 0.3, green: 0.28, blue: 0.4).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
            
            // Zodiac sign segments
            ForEach(0..<12) { index in
                let sign = zodiacSigns[index]
                let startAngle = Angle(degrees: Double(index) * 30 - 90)
                let midAngle = Angle(degrees: Double(index) * 30 + 15 - 90)
                
                // Sign divider lines
                Path { path in
                    let center = CGPoint(x: size/2, y: size/2)
                    let innerRadius = size * 0.35
                    let outerRadius = size * 0.48
                    
                    let startX = center.x + cos(startAngle.radians) * innerRadius
                    let startY = center.y + sin(startAngle.radians) * innerRadius
                    let endX = center.x + cos(startAngle.radians) * outerRadius
                    let endY = center.y + sin(startAngle.radians) * outerRadius
                    
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                
                // Sign symbol
                let symbolRadius = size * 0.42
                let symbolX = size/2 + cos(midAngle.radians) * symbolRadius
                let symbolY = size/2 + sin(midAngle.radians) * symbolRadius
                
                Text(sign.symbol)
                    .font(.system(size: 16))
                    .foregroundColor(elementColor(for: sign.element).opacity(0.8))
                    .position(x: symbolX, y: symbolY)
            }
        }
    }
    
    private var houseDivisions: some View {
        ZStack {
            // House number ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: size * 0.7, height: size * 0.7)
            
            // House cusps and numbers
            if let risingSignIndex = risingSign?.index {
                ForEach(0..<12) { houseIndex in
                    let signIndex = (risingSignIndex + houseIndex) % 12
                    let angle = Angle(degrees: Double(signIndex) * 30 - 90)
                    let midAngle = Angle(degrees: Double(signIndex) * 30 + 15 - 90)
                    
                    // House cusp line
                    Path { path in
                        let center = CGPoint(x: size/2, y: size/2)
                        let innerRadius = size * 0.15
                        let outerRadius = size * 0.35
                        
                        let startX = center.x + cos(angle.radians) * innerRadius
                        let startY = center.y + sin(angle.radians) * innerRadius
                        let endX = center.x + cos(angle.radians) * outerRadius
                        let endY = center.y + sin(angle.radians) * outerRadius
                        
                        path.move(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: endX, y: endY))
                    }
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    
                    // House number
                    let numberRadius = size * 0.25
                    let numberX = size/2 + cos(midAngle.radians) * numberRadius
                    let numberY = size/2 + sin(midAngle.radians) * numberRadius
                    
                    Text("\(houseIndex + 1)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.3))
                        .position(x: numberX, y: numberY)
                }
            }
        }
    }
    
    private var planetPositions: some View {
        ZStack {
            ForEach(planets, id: \.planet) { position in
                let angle = Angle(degrees: position.longitude - 90)
                let radius = size * 0.32
                let x = size/2 + cos(angle.radians) * radius
                let y = size/2 + sin(angle.radians) * radius
                
                // Planet symbol with glow
                ZStack {
                    // Glow
                    Circle()
                        .fill(elementColor(for: position.sign.element).opacity(0.3))
                        .frame(width: 24, height: 24)
                        .blur(radius: 4)
                    
                    // Symbol
                    Text(position.planet.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(elementColor(for: position.sign.element))
                }
                .position(x: x, y: y)
            }
        }
    }
    
    private var centerCircle: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.18),
                            Color(red: 0.05, green: 0.05, blue: 0.1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.28, height: size * 0.28)
            
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: size * 0.28, height: size * 0.28)
            
            // Rising sign indicator
            if let rising = risingSign {
                VStack(spacing: 2) {
                    Text("ASC")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                    Text(rising.symbol)
                        .font(.system(size: 24))
                        .foregroundColor(elementColor(for: rising.element))
                }
            }
        }
    }
    
    private func elementColor(for element: Element) -> Color {
        switch element {
        case .fire:
            return Color(red: 0.95, green: 0.5, blue: 0.4)
        case .earth:
            return Color(red: 0.6, green: 0.75, blue: 0.5)
        case .air:
            return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .water:
            return Color(red: 0.5, green: 0.55, blue: 0.85)
        }
    }
}

// MARK: - Chart Element Detail Sheet

struct ChartElementDetailSheet: View {
    let element: ChartElementSelection
    let chart: BirthChart
    let profile: UserProfile
    let contexts: [UserContext]
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = AIReadingService.shared
    @State private var explanation: String?
    @State private var isLoading = true
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.06, green: 0.06, blue: 0.1)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    elementHeader
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Content
                    if isLoading {
                        loadingView
                    } else if let explanation = explanation {
                        explanationContent(explanation)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(24)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                generateExplanation()
            }
        }
    }
    
    private var elementHeader: some View {
        HStack(spacing: 16) {
            // Symbol
            ZStack {
                Circle()
                    .fill(elementColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Text(elementSymbol)
                    .font(.system(size: 28))
                    .foregroundColor(elementColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(elementTitle)
                    .font(.custom("Georgia", size: 22))
                    .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
                
                Text(elementSubtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
            }
            
            Spacer()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.7, green: 0.65, blue: 0.8)))
                .scaleEffect(1.2)
            
            Text("Understanding this placement...")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func explanationContent(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current context label
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text("As of \(formattedCurrentDate)")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
            
            markdownText(text)
        }
    }
    
    /// Renders markdown text with proper styling for bold, italic, and bullet points
    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if let attributedString = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributedString)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.8, green: 0.78, blue: 0.75))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // Fallback to plain text if markdown parsing fails
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.8, green: 0.78, blue: 0.75))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Computed Properties
    
    private var elementTitle: String {
        switch element {
        case .planet(let pos):
            return "\(pos.planet.rawValue) in \(pos.sign.rawValue)"
        case .bigThree(let type, let sign, _):
            return "\(type) in \(sign.rawValue)"
        case .aspect(let asp):
            return "\(asp.planet1.rawValue) \(asp.type.rawValue) \(asp.planet2.rawValue)"
        case .evolutionaryPoint(let title, let pos):
            return "\(title) in \(pos.sign.rawValue)"
        }
    }
    
    private var elementSubtitle: String {
        switch element {
        case .planet(let pos):
            var sub = pos.formattedDegree
            if let house = pos.house { sub += " • House \(house)" }
            if pos.isRetrograde { sub += " • Retrograde" }
            return sub
        case .bigThree(let type, _, _):
            switch type {
            case "Sun": return "Your core identity"
            case "Moon": return "Your emotional nature"
            case "Rising": return "How you meet the world"
            default: return ""
            }
        case .aspect(let asp):
            return "\(String(format: "%.1f", asp.orb))° orb"
        case .evolutionaryPoint(let title, let pos):
            var sub = pos.formattedDegree
            if let house = pos.house { sub += " • House \(house)" }
            if title == "North Node" { sub += " • Soul's direction" }
            else if title == "South Node" { sub += " • Past patterns" }
            else if title == "Pluto" { sub += " • Transformation" }
            return sub
        }
    }
    
    private var elementSymbol: String {
        switch element {
        case .planet(let pos):
            return pos.planet.symbol
        case .bigThree(let type, let sign, _):
            switch type {
            case "Sun": return "☉"
            case "Moon": return "☽"
            case "Rising": return sign.symbol
            default: return "✧"
            }
        case .aspect(let asp):
            return asp.type.symbol
        case .evolutionaryPoint(_, let pos):
            return pos.planet.symbol
        }
    }
    
    private var elementColor: Color {
        switch element {
        case .planet(let pos):
            return colorForElement(pos.sign.element)
        case .bigThree(_, let sign, _):
            return colorForElement(sign.element)
        case .aspect(let asp):
            return colorForAspect(asp.type)
        case .evolutionaryPoint(let title, _):
            switch title {
            case "North Node": return Color(red: 0.4, green: 0.7, blue: 0.5)
            case "South Node": return Color(red: 0.7, green: 0.5, blue: 0.4)
            default: return Color(red: 0.6, green: 0.4, blue: 0.7)
            }
        }
    }
    
    private var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func colorForElement(_ element: Element) -> Color {
        switch element {
        case .fire: return Color(red: 0.95, green: 0.5, blue: 0.4)
        case .earth: return Color(red: 0.6, green: 0.75, blue: 0.5)
        case .air: return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .water: return Color(red: 0.5, green: 0.55, blue: 0.85)
        }
    }
    
    private func colorForAspect(_ type: AspectType) -> Color {
        switch type {
        case .conjunction: return Color(red: 0.9, green: 0.8, blue: 0.4)
        case .sextile: return Color(red: 0.4, green: 0.7, blue: 0.9)
        case .square: return Color(red: 0.9, green: 0.4, blue: 0.4)
        case .trine: return Color(red: 0.4, green: 0.8, blue: 0.5)
        case .opposition: return Color(red: 0.9, green: 0.5, blue: 0.3)
        }
    }
    
    // MARK: - AI Generation
    
    private func generateExplanation() {
        Task {
            do {
                let result = try await aiService.generateElementExplanation(
                    element: element,
                    chart: chart,
                    profile: profile,
                    contexts: contexts
                )
                await MainActor.run {
                    explanation = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    explanation = "Unable to generate explanation. Please try again."
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ChartWheelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Journal Stat Card

struct JournalStatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        // Create a mock chart for preview
        let mockChart = BirthChart(
            userId: UUID(),
            chartType: "FULL_NATAL",
            metadata: ChartMetadata(
                birthDate: Date(),
                birthTimeInput: "14:30",
                birthPlaceInput: "New York, NY",
                latitude: 40.7128,
                longitude: -74.0060,
                timezone: "America/New_York",
                houseSystem: "PLACIDUS",
                nodeType: "true",
                utcDateTimeUsed: Date(),
                julianDay: nil,
                assumptions: []
            ),
            angles: nil,
            houses: nil,
            planets: [
                PlanetaryPosition(planet: .sun, longitude: 280, sign: .capricorn, degreeInSign: 10, house: 10, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .moon, longitude: 45, sign: .taurus, degreeInSign: 15, house: 2, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .mercury, longitude: 265, sign: .sagittarius, degreeInSign: 25, house: 9, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .venus, longitude: 300, sign: .capricorn, degreeInSign: 30, house: 10, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .mars, longitude: 180, sign: .libra, degreeInSign: 0, house: 7, isRetrograde: false, signUncertain: false, possibleSigns: nil),
            ],
            aspects: nil,
            evolutionaryCore: EvolutionaryCore(
                pluto: PlanetaryPosition(planet: .pluto, longitude: 290, sign: .capricorn, degreeInSign: 20, house: 10, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                northNode: PlanetaryPosition(planet: .northNode, longitude: 90, sign: .cancer, degreeInSign: 0, house: 4, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                southNode: PlanetaryPosition(planet: .southNode, longitude: 270, sign: .capricorn, degreeInSign: 0, house: 10, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                moon: nil,
                sun: nil,
                risingSign: .aries,
                notes: ["Placidus houses used"]
            )
        )
        
        BirthChartView(initialChart: mockChart)
    }
}

