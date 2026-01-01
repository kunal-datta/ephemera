//
//  HomeView.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData

// MARK: - Daily Reading Cache

/// Stores the daily reading with its date for caching
struct CachedDailyReading: Codable {
    let reading: String
    let date: String // Format: yyyy-MM-dd
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    var isFromToday: Bool {
        let todayString = CachedDailyReading.dateFormatter.string(from: Date())
        return date == todayString
    }
}

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query private var birthCharts: [BirthChart]
    @Query private var allContexts: [UserContext]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isGeneratingChart = false
    @State private var showChart = false
    @State private var showProfile = false
    @State private var showJournal = false
    @State private var generatedChart: BirthChart?
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Daily reading state
    @State private var dailyReading: String?
    @State private var isLoadingReading = false
    @State private var readingError: String?
    
    // Animation state
    @State private var contentAppeared = false
    
    private var currentProfile: UserProfile? {
        profiles.first
    }
    
    private var currentChart: BirthChart? {
        birthCharts.first
    }
    
    private var userContexts: [UserContext] {
        guard let profile = currentProfile else { return [] }
        return allContexts.filter { $0.userId == profile.id }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.09),
                    Color(red: 0.06, green: 0.05, blue: 0.14),
                    Color(red: 0.03, green: 0.03, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            StarFieldView()
                .opacity(0.25)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with date
                    headerSection
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    
                    // Reading of the Day
                    readingOfTheDayCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: contentAppeared)
                    
                    // Journal prompt
                    journalPromptCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: contentAppeared)
                    
                    // See my chart
                    chartCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: contentAppeared)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showProfile = true }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                }
                .opacity(currentProfile != nil ? 1 : 0)
            }
        }
        .navigationDestination(isPresented: $showChart) {
            if let chart = generatedChart ?? currentChart {
                BirthChartView(initialChart: chart)
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let profile = currentProfile {
                ProfileEditView(profile: profile) {
                    generatedChart = nil
                }
            }
        }
        .sheet(isPresented: $showJournal) {
            if let profile = currentProfile {
                JournalEntryView(profile: profile) {
                    // Journal entry completed
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .preferredColorScheme(.dark)
        .onAppear {
            contentAppeared = true
            loadDailyReading()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("ephemera")
                .font(.custom("Georgia", size: 28))
                .fontWeight(.light)
                .tracking(3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.92, blue: 0.88),
                            Color(red: 0.82, green: 0.78, blue: 0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            if let profile = currentProfile {
                Text("Welcome, \(profile.name)")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
            }
            
            Text(formattedDate)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.35))
                .tracking(0.5)
        }
    }
    
    // MARK: - Reading of the Day Card
    
    private var readingOfTheDayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.7, green: 0.6, blue: 0.85))
                
                Text("READING OF THE DAY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .tracking(1.5)
                
                Spacer()
            }
            
            // Content
            if isLoadingReading {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Reading the stars...")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 20)
            } else if let reading = dailyReading {
                Text(reading)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.8))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let error = readingError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unable to load today's reading")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.5))
                    
                    Button(action: { loadDailyReading(forceRefresh: true) }) {
                        Text("Try again")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.7, green: 0.6, blue: 0.85))
                    }
                }
            } else if currentChart == nil {
                Text("Generate your birth chart to unlock personalized daily readings")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.45))
                    .italic()
            } else {
                Text("Your daily guidance is on its way...")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.45))
                    .italic()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.7, green: 0.6, blue: 0.85).opacity(0.3),
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
    
    // MARK: - Journal Prompt Card
    
    private var journalPromptCard: some View {
        Button(action: { showJournal = true }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.45, green: 0.6, blue: 0.5).opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "leaf")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.5, green: 0.7, blue: 0.55))
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text("How are you feeling today?")
                        .font(.custom("Georgia", size: 17))
                        .foregroundColor(Color.white.opacity(0.9))
                    
                    Text("Take a moment to check in")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(currentProfile == nil)
        .opacity(currentProfile == nil ? 0.5 : 1)
    }
    
    // MARK: - Chart Card
    
    private var chartCard: some View {
        Button(action: handleSeeMyChart) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.85, blue: 0.7).opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    if isGeneratingChart {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.95, green: 0.85, blue: 0.7)))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.7))
                    }
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(isGeneratingChart ? "Calculating..." : "See my chart")
                        .font(.custom("Georgia", size: 17))
                        .foregroundColor(Color.white.opacity(0.9))
                    
                    if currentChart != nil {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(red: 0.4, green: 0.7, blue: 0.5))
                                .frame(width: 5, height: 5)
                            Text("Chart calculated")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                    } else {
                        Text("Explore your birth chart")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGeneratingChart || currentProfile == nil)
        .opacity(currentProfile == nil ? 0.5 : 1)
    }
    
    // MARK: - Daily Reading Logic
    
    private func loadDailyReading(forceRefresh: Bool = false) {
        guard let chart = currentChart, let profile = currentProfile else { return }
        
        // Check cached reading first
        if !forceRefresh, let cached = loadCachedReading(), cached.isFromToday {
            dailyReading = cached.reading
            return
        }
        
        // Generate new reading
        isLoadingReading = true
        readingError = nil
        
        Task {
            do {
                let reading = try await AIReadingService.shared.generateDailyReading(
                    chart: chart,
                    profile: profile,
                    contexts: userContexts
                )
                
                await MainActor.run {
                    dailyReading = reading
                    isLoadingReading = false
                    saveCachedReading(reading)
                }
            } catch {
                await MainActor.run {
                    readingError = error.localizedDescription
                    isLoadingReading = false
                }
            }
        }
    }
    
    private func loadCachedReading() -> CachedDailyReading? {
        guard let data = UserDefaults.standard.data(forKey: "cachedDailyReading") else { return nil }
        return try? JSONDecoder().decode(CachedDailyReading.self, from: data)
    }
    
    private func saveCachedReading(_ reading: String) {
        let todayString = CachedDailyReading.dateFormatter.string(from: Date())
        let cached = CachedDailyReading(reading: reading, date: todayString)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: "cachedDailyReading")
        }
    }
    
    // MARK: - Chart Actions
    
    private func handleSeeMyChart() {
        // If we already have a chart, just show it
        if let existingChart = currentChart {
            generatedChart = existingChart
            showChart = true
            return
        }
        
        // Otherwise, generate a new chart
        guard let profile = currentProfile else { return }
        
        isGeneratingChart = true
        
        Task {
            await generateAndSaveChart(for: profile)
        }
    }
    
    private func generateAndSaveChart(for profile: UserProfile) async {
        let input = ChartInput(
            name: profile.name,
            birthDate: profile.dateOfBirth,
            birthTime: profile.timeOfBirth,
            birthTimeUnknown: profile.timeOfBirthUnknown,
            birthPlace: profile.placeOfBirth,
            latitude: profile.placeOfBirthLatitude,
            longitude: profile.placeOfBirthLongitude,
            timezone: profile.placeOfBirthTimezone,
            nodeType: .trueNode
        )
        
        let result = ChartCore.shared.generateChart(input: input)
        
        await MainActor.run {
            isGeneratingChart = false
            
            switch result.status {
            case .ok:
                if let chart = BirthChart.from(result: result, userId: profile.id) {
                    for existingChart in birthCharts where existingChart.chartType == chart.chartType {
                        modelContext.delete(existingChart)
                    }
                    
                    modelContext.insert(chart)
                    
                    Task {
                        do {
                            try await FirestoreService.shared.deleteBirthCharts(ofType: chart.chartType)
                            try await FirestoreService.shared.saveBirthChart(chart)
                            print("✅ Birth chart saved to Firestore")
                        } catch {
                            print("❌ Failed to save chart to Firestore: \(error)")
                        }
                    }
                    
                    generatedChart = chart
                    showChart = true
                    
                    // Now that we have a chart, load the daily reading
                    loadDailyReading()
                } else {
                    errorMessage = "Failed to create birth chart from calculation"
                    showError = true
                }
                
            case .needsGeocoding:
                errorMessage = "Location data is incomplete. Please update your birth place."
                showError = true
                
            case .error:
                errorMessage = result.errors.joined(separator: "\n")
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .modelContainer(for: [UserProfile.self, BirthChart.self, UserContext.self], inMemory: true)
    }
}
