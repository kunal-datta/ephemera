//
//  JournalHistoryView.swift
//  ephemera
//
//  View for displaying past journal entries, activity trends, and AI insights.
//
//  Created by Kunal_Datta on 31/12/25.
//

import SwiftUI
import SwiftData

struct JournalHistoryView: View {
    let profile: UserProfile
    
    @Environment(\.dismiss) private var dismiss
    @Query private var allContexts: [UserContext]
    @Query private var birthCharts: [BirthChart]
    
    @State private var selectedTab = 0
    @State private var journalInsight: String?
    @State private var isLoadingInsight = false
    @State private var lastInsightEntryCount = 0
    @State private var showNewEntry = false
    
    private var userContexts: [UserContext] {
        allContexts
            .filter { $0.userId == profile.id && $0.promptType == ContextPromptType.journal.rawValue }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var currentChart: BirthChart? {
        birthCharts.first
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.04, blue: 0.07)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab picker
                tabPicker
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // Content
                if userContexts.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $selectedTab) {
                        entriesListView
                            .tag(0)
                        
                        insightsView
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showNewEntry) {
            JournalEntryView(profile: profile) {
                // Entry saved - will auto-refresh via @Query
            }
        }
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
            
            Text("Journal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: { showNewEntry = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "Entries", index: 0)
            tabButton(title: "Insights", index: 1)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 24)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        
        return Button(action: {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "book.closed")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color.white.opacity(0.3))
            
            Text("No entries yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            Text("Start journaling to track your patterns")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.4))
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Entries List
    
    private var entriesListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Add new entry button
                addEntryButton
                
                // Entries
                LazyVStack(spacing: 12) {
                    ForEach(userContexts, id: \.id) { entry in
                        EntryCard(entry: entry)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    private var addEntryButton: some View {
        Button(action: { showNewEntry = true }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.white.opacity(0.6))
                
                Text("New Entry")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))
                
                Spacer()
                
                Text("How are you feeling?")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Insights View
    
    private var insightsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Activity Calendar
                activityCalendar
                
                // Stats row
                statsRow
                
                // Mood breakdown
                moodBreakdown
                
                // Mood patterns over time chart
                moodPatternsOverTimeChart
                
                // Focus areas
                focusAreasBreakdown
                
                // Focus areas over time chart
                focusAreasOverTimeChart
                
                // AI Insight
                aiInsightCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .onAppear {
            if userContexts.count >= 2 && (journalInsight == nil || lastInsightEntryCount != userContexts.count) {
                generateInsight()
            }
        }
        .onChange(of: userContexts.count) { oldCount, newCount in
            // Regenerate insight when new entries are added
            if newCount >= 2 && newCount != lastInsightEntryCount {
                generateInsight()
            }
        }
    }
    
    // MARK: - Activity Calendar
    
    private var activityCalendar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                
                Spacer()
                
                Text("Last 4 weeks")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            
            // Calendar grid - 8 weeks x 7 days
            ActivityCalendarGrid(
                allDays: generateAllDays(),
                activityColorProvider: activityColor
            )
            .frame(height: 220)
            
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
    
    private func generateAllDays() -> [ActivityDayData] {
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
        
        return userContexts.filter { entry in
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
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(userContexts.count)", label: "Entries")
            StatCard(value: calculateStreak(), label: "Streak")
            StatCard(value: "\(uniqueDays())", label: "Days")
        }
    }
    
    private func uniqueDays() -> Int {
        let calendar = Calendar.current
        let uniqueDates = Set(userContexts.map { calendar.startOfDay(for: $0.createdAt) })
        return uniqueDates.count
    }
    
    // MARK: - Mood Breakdown
    
    private var moodBreakdown: some View {
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
    
    // MARK: - Mood Patterns Over Time Chart
    
    private var moodPatternsOverTimeChart: some View {
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
    
    // MARK: - Focus Areas Breakdown
    
    private var focusAreasBreakdown: some View {
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
    
    // MARK: - Focus Areas Over Time Chart
    
    private var focusAreasOverTimeChart: some View {
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
    
    // MARK: - AI Insight Card
    
    private var aiInsightCard: some View {
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
            } else if userContexts.count < 2 {
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
    
    private func generateInsight() {
        guard let chart = currentChart, !isLoadingInsight else { return }
        
        isLoadingInsight = true
        let currentCount = userContexts.count
        
        Task {
            do {
                let insight = try await AIReadingService.shared.generateJournalInsight(
                    chart: chart,
                    profile: profile,
                    journalEntries: userContexts
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
    
    // MARK: - Helper Functions
    
    private func calculateMoodCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in userContexts {
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
            } else if let mood = entry.mood, !mood.isEmpty {
                counts[mood, default: 0] += 1
            }
        }
        return counts
    }
    
    private func calculateLifeAreaCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in userContexts {
            if let tags = entry.tags {
                let areas = tags.components(separatedBy: ", ")
                for area in areas {
                    let trimmed = area.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        counts[trimmed, default: 0] += 1
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
    
    private func calculateStreak() -> String {
        guard !userContexts.isEmpty else { return "0" }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Build set of unique days with entries
        var datesWithEntries = Set<Date>()
        for entry in userContexts {
            datesWithEntries.insert(calendar.startOfDay(for: entry.createdAt))
        }
        
        // Streak starts from today if there's an entry, otherwise from yesterday
        // This gives a "grace period" - if you journaled yesterday but not yet today, streak continues
        var streak = 0
        var checkDate: Date
        
        if datesWithEntries.contains(today) {
            checkDate = today
        } else if datesWithEntries.contains(yesterday) {
            checkDate = yesterday
        } else {
            return "0"
        }
        
        // Count consecutive days going backwards
        while datesWithEntries.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        return "\(streak)"
    }
    
    // MARK: - Over Time Data Calculations
    
    private func calculateMoodOverTime() -> [DayMoodChartData] {
        let calendar = Calendar.current
        
        // Group entries by day
        var dayData: [Date: [String: Int]] = [:]
        
        for entry in userContexts {
            let day = calendar.startOfDay(for: entry.createdAt)
            if dayData[day] == nil {
                dayData[day] = [:]
            }
            
            // Extract moods from entry
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
            } else if let mood = entry.mood, !mood.isEmpty {
                dayData[day]![mood, default: 0] += 1
            }
        }
        
        // Sort by date and limit to last 14 days with data
        let sortedDays = dayData.keys.sorted()
        let limitedDays = Array(sortedDays.suffix(14))
        
        return limitedDays.map { DayMoodChartData(date: $0, moodCounts: dayData[$0] ?? [:]) }
    }
    
    private func calculateFocusAreasOverTime() -> [DayAreaChartData] {
        let calendar = Calendar.current
        
        // Group entries by day
        var dayData: [Date: [String: Int]] = [:]
        
        for entry in userContexts {
            let day = calendar.startOfDay(for: entry.createdAt)
            if dayData[day] == nil {
                dayData[day] = [:]
            }
            
            // Extract areas from tags
            if let tags = entry.tags {
                let areas = tags.components(separatedBy: ", ")
                for area in areas {
                    let trimmed = area.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        dayData[day]![trimmed, default: 0] += 1
                    }
                }
            }
        }
        
        // Sort by date and limit to last 14 days with data
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
}

// MARK: - Time Chart Data Structures

struct DayMoodChartData {
    let date: Date
    var moodCounts: [String: Int]
}

struct DayAreaChartData {
    let date: Date
    var areaCounts: [String: Int]
}

// MARK: - Mood Line Shape

struct MoodLineShape: Shape {
    let dataPoints: [DayMoodChartData]
    let mood: String
    let width: CGFloat
    let height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !dataPoints.isEmpty else { return path }
        
        let maxCount = dataPoints.flatMap { $0.moodCounts.values }.max() ?? 1
        var isFirstPoint = true
        
        for (index, day) in dataPoints.enumerated() {
            let count = day.moodCounts[mood] ?? 0
            if count > 0 {
                let xPos = dataPoints.count > 1
                    ? width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                    : width / 2
                let yPos = height - (height * CGFloat(count) / CGFloat(max(maxCount, 3)))
                
                if isFirstPoint {
                    path.move(to: CGPoint(x: xPos, y: yPos))
                    isFirstPoint = false
                } else {
                    path.addLine(to: CGPoint(x: xPos, y: yPos))
                }
            }
        }
        
        return path
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
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

// MARK: - Activity Calendar Grid

struct ActivityCalendarGrid: View {
    let allDays: [ActivityDayData]
    let activityColorProvider: (Int) -> Color
    
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Day labels row
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Week rows (4 weeks)
            ForEach(0..<4, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    // 7 days in the week
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let index = weekIndex * 7 + dayIndex
                        let dayData = index < allDays.count ? allDays[index] : nil
                        let isToday = isToday(dayData)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cellColor(for: dayData))
                            
                            // Today indicator - white ring
                            if isToday {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(2)
                        .shadow(color: isToday ? Color.white.opacity(0.3) : Color.clear, radius: 4)
                    }
                }
            }
        }
    }
    
    private func isToday(_ dayData: ActivityDayData?) -> Bool {
        guard let dayData = dayData else { return false }
        let calendar = Calendar.current
        return calendar.isDateInToday(dayData.date)
    }
    
    private func cellColor(for dayData: ActivityDayData?) -> Color {
        guard let dayData = dayData else {
            return Color.white.opacity(0.03)
        }
        if dayData.isFuture {
            return Color.white.opacity(0.03)
        }
        return activityColorProvider(dayData.count)
    }
}

struct ActivityDayData {
    let date: Date
    let count: Int
    let isFuture: Bool
}

// MARK: - Entry Card

struct EntryCard: View {
    let entry: UserContext
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                if hasAdditionalContent {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                HStack(spacing: 14) {
                    // Mood icons
                    HStack(spacing: -4) {
                        ForEach(Array(moodSymbols.prefix(3).enumerated()), id: \.offset) { index, symbol in
                            Image(systemName: symbol.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(symbol.1)
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(symbol.1.opacity(0.15))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(red: 0.04, green: 0.04, blue: 0.07), lineWidth: 2)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedDate)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(formattedAreas)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if hasAdditionalContent {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded, let thoughts = additionalThoughts, !thoughts.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.06))
                    
                    Text(thoughts)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineSpacing(4)
                        .padding(16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: entry.createdAt)
    }
    
    private var moodSymbols: [(String, Color)] {
        var symbols: [(String, Color)] = []
        
        if let response = entry.response.range(of: "Moods: ") {
            let afterMoods = entry.response[response.upperBound...]
            if let periodIndex = afterMoods.firstIndex(of: ".") {
                let moodsString = String(afterMoods[..<periodIndex])
                let moods = moodsString.components(separatedBy: ", ")
                for mood in moods {
                    let trimmed = mood.trimmingCharacters(in: .whitespaces)
                    symbols.append((moodSymbol(for: trimmed), moodColor(for: trimmed)))
                }
            }
        }
        
        if symbols.isEmpty, let mood = entry.mood {
            symbols.append((moodSymbol(for: mood), moodColor(for: mood)))
        }
        
        return symbols
    }
    
    private var formattedAreas: String {
        entry.tags ?? ""
    }
    
    private var hasAdditionalContent: Bool {
        additionalThoughts != nil && !additionalThoughts!.isEmpty
    }
    
    private var additionalThoughts: String? {
        if let range = entry.response.range(of: "Additional thoughts: ") {
            return String(entry.response[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
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
}

// MARK: - Mood Over Time Chart Content

struct MoodOverTimeChartContent: View {
    let timeData: [DayMoodChartData]
    let topMoods: [String]
    let moodColorProvider: (String) -> Color
    let formatDate: (Date) -> String
    
    var body: some View {
        VStack(spacing: 0) {
            // Chart area
            GeometryReader { geo in
                chartContent(width: geo.size.width)
            }
            .frame(height: 120)
            
            // X-axis labels
            xAxisLabels
                .padding(.top, 4)
            
            // Legend
            legendView
                .padding(.top, 8)
        }
    }
    
    private func chartContent(width: CGFloat) -> some View {
        let height: CGFloat = 120
        let maxGlobalCount = timeData.flatMap { $0.moodCounts.values }.max() ?? 1
        
        return ZStack {
            // Grid lines
            gridLines(height: height)
            
            // Lines for each mood
            ForEach(topMoods, id: \.self) { mood in
                MoodLineShape(
                    dataPoints: timeData,
                    mood: mood,
                    width: width,
                    height: height
                )
                .stroke(moodColorProvider(mood), lineWidth: 2)
            }
            
            // Dots for each mood
            ForEach(topMoods, id: \.self) { mood in
                moodDots(mood: mood, width: width, height: height, maxCount: maxGlobalCount)
            }
        }
        .frame(height: height)
    }
    
    private func gridLines(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                Divider()
                    .background(Color.white.opacity(0.06))
                if i < 3 {
                    Spacer()
                }
            }
        }
        .frame(height: height)
    }
    
    private func moodDots(mood: String, width: CGFloat, height: CGFloat, maxCount: Int) -> some View {
        ForEach(Array(timeData.enumerated()), id: \.offset) { index, day in
            let count = day.moodCounts[mood] ?? 0
            if count > 0 {
                Circle()
                    .fill(moodColorProvider(mood))
                    .frame(width: 6, height: 6)
                    .position(
                        x: timeData.count > 1 ? width * CGFloat(index) / CGFloat(timeData.count - 1) : width / 2,
                        y: height - (height * CGFloat(count) / CGFloat(max(maxCount, 3)))
                    )
            }
        }
    }
    
    private var xAxisLabels: some View {
        HStack {
            ForEach(Array(timeData.enumerated()), id: \.offset) { index, day in
                if index == 0 || index == timeData.count - 1 || index == timeData.count / 2 {
                    Text(formatDate(day.date))
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.3))
                    if index < timeData.count - 1 {
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var legendView: some View {
        HStack(spacing: 12) {
            ForEach(topMoods, id: \.self) { mood in
                HStack(spacing: 4) {
                    Circle()
                        .fill(moodColorProvider(mood))
                        .frame(width: 6, height: 6)
                    Text(mood)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - Focus Areas Over Time Chart Content

struct FocusAreasOverTimeChartContent: View {
    let timeData: [DayAreaChartData]
    let topAreas: [String]
    let areaColorProvider: (String) -> Color
    let formatDate: (Date) -> String
    
    var body: some View {
        VStack(spacing: 0) {
            // Chart area - stacked bar chart
            GeometryReader { geo in
                barChart(width: geo.size.width)
            }
            .frame(height: 120)
            
            // X-axis labels
            xAxisLabels
                .padding(.top, 4)
            
            // Legend
            legendView
                .padding(.top, 8)
        }
    }
    
    private func barChart(width: CGFloat) -> some View {
        let height: CGFloat = 120
        let barWidth = calculateBarWidth(totalWidth: width)
        let maxTotal = calculateMaxTotal()
        
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(timeData.enumerated()), id: \.offset) { index, day in
                barStack(day: day, barWidth: barWidth, height: height, maxTotal: maxTotal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)
    }
    
    private func calculateBarWidth(totalWidth: CGFloat) -> CGFloat {
        max(8, min(24, (totalWidth - CGFloat(timeData.count - 1) * 4) / CGFloat(timeData.count)))
    }
    
    private func calculateMaxTotal() -> Int {
        timeData.map { day in
            topAreas.reduce(0) { $0 + (day.areaCounts[$1] ?? 0) }
        }.max() ?? 1
    }
    
    private func barStack(day: DayAreaChartData, barWidth: CGFloat, height: CGFloat, maxTotal: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(topAreas.reversed(), id: \.self) { area in
                let count = day.areaCounts[area] ?? 0
                if count > 0 {
                    Rectangle()
                        .fill(areaColorProvider(area))
                        .frame(height: height * CGFloat(count) / CGFloat(max(maxTotal, 1)))
                }
            }
        }
        .frame(width: barWidth)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
    
    private var labelIndices: [Int] {
        timeData.count <= 5 ? Array(0..<timeData.count) : [0, timeData.count / 2, timeData.count - 1]
    }
    
    private var xAxisLabels: some View {
        HStack {
            ForEach(Array(timeData.enumerated()), id: \.offset) { index, day in
                if labelIndices.contains(index) {
                    Text(formatDate(day.date))
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.3))
                    if index < timeData.count - 1 && labelIndices.contains(index) {
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var legendView: some View {
        FlowLayout(spacing: 8) {
            ForEach(topAreas, id: \.self) { area in
                HStack(spacing: 4) {
                    Circle()
                        .fill(areaColorProvider(area))
                        .frame(width: 6, height: 6)
                    Text(area)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    JournalHistoryView(
        profile: UserProfile(
            name: "Test User",
            email: "test@example.com",
            dateOfBirth: Date(),
            authProvider: "email"
        )
    )
}
