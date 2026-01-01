//
//  ChartReadingView.swift
//  ephemera
//
//  Displays the AI-generated personalized reading for a birth chart.
//  This is the interpretive, narrative view that makes astrology accessible.
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData

struct ChartReadingView: View {
    let chart: BirthChart
    let profile: UserProfile
    
    @Query private var contexts: [UserContext]
    @StateObject private var readingService = AIReadingService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var reading: AIReading?
    @State private var showError = false
    @State private var expandedSections: Set<UUID> = []
    @State private var hasAppeared = false
    @State private var currentCardIndex = 0
    
    // Filter contexts for this user
    private var userContexts: [UserContext] {
        contexts.filter { $0.userId == profile.id }
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
                .opacity(0.2)
            
            if readingService.isGenerating {
                loadingView
            } else if let reading = reading {
                readingContent(reading)
            } else if let error = readingService.error {
                errorView(error)
            } else {
                // Initial state - will auto-generate
                loadingView
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
                Text("Your Reading")
                    .font(.custom("Georgia", size: 18))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                generateReading()
            }
        }
        .alert("Unable to Generate Reading", isPresented: $showError) {
            Button("Try Again") {
                generateReading()
            }
            Button("Go Back", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(readingService.error ?? "An unexpected error occurred.")
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            // Animated cosmic loader
            ZStack {
                Circle()
                    .stroke(Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.2), lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.7, green: 0.6, blue: 0.8),
                                Color(red: 0.5, green: 0.45, blue: 0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(hasAppeared ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: hasAppeared)
                
                Text("✧")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.8, green: 0.75, blue: 0.9))
            }
            
            VStack(spacing: 8) {
                Text("Interpreting the stars...")
                    .font(.custom("Georgia", size: 20))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
                
                Text("Weaving together your cosmic story")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
            }
        }
    }
    
    // MARK: - Reading Content
    
    private func readingContent(_ reading: AIReading) -> some View {
        VStack(spacing: 0) {
            // Header at top
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            // Swipeable cards
            if !reading.sections.isEmpty {
                TabView(selection: $currentCardIndex) {
                    ForEach(Array(reading.sections.enumerated()), id: \.element.id) { index, section in
                        swipeableSectionCard(section, index: index, total: reading.sections.count)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentCardIndex)
                
                // Custom page indicator
                pageIndicator(total: reading.sections.count)
                    .padding(.bottom, 40)
            } else {
                // Fallback: show raw content if parsing failed
                ScrollView(showsIndicators: false) {
                    rawContentCard(reading.content)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Page Indicator
    
    private func pageIndicator(total: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == currentCardIndex 
                        ? Color(red: 0.7, green: 0.65, blue: 0.8) 
                        : Color.white.opacity(0.2))
                    .frame(width: index == currentCardIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCardIndex)
            }
        }
        .padding(.top, 16)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Decorative element
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.4))
                    .frame(width: 40, height: 1)
                
                Text("✧")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.7, green: 0.65, blue: 0.8))
                
                Rectangle()
                    .fill(Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.4))
                    .frame(width: 40, height: 1)
            }
            
            Text("A Reading for \(profile.name)")
                .font(.custom("Georgia", size: 24))
                .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
            
            if let metadata = chart.metadata {
                Text(formatBirthInfo(metadata))
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 8)
    }
    
    private func swipeableSectionCard(_ section: ReadingSection, index: Int, total: Int) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Card number indicator
                HStack {
                    Text("\(index + 1) of \(total)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.55))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.05))
                        )
                    
                    Spacer()
                }
                
                // Section header
                Text(cleanSectionTitle(section.title))
                    .font(.custom("Georgia", size: 22))
                    .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
                
                // Section body with markdown rendering
                markdownText(section.body)
                
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func rawContentCard(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            markdownText(content)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
        )
    }
    
    /// Renders markdown text with proper styling for bold, italic, and bullet points
    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if let attributedString = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributedString)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(red: 0.75, green: 0.73, blue: 0.70))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // Fallback to plain text if markdown parsing fails
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(red: 0.75, green: 0.73, blue: 0.70))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Color(red: 0.9, green: 0.6, blue: 0.5))
            
            Text("Unable to Generate Reading")
                .font(.custom("Georgia", size: 20))
                .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: generateReading) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.1))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.92, green: 0.88, blue: 0.82))
                    )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func generateReading() {
        Task {
            do {
                reading = try await readingService.generateNatalReading(
                    chart: chart,
                    profile: profile,
                    contexts: userContexts
                )
            } catch {
                showError = true
            }
        }
    }
    
    private func formatBirthInfo(_ metadata: ChartMetadata) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        if let tzId = metadata.timezone, let tz = TimeZone(identifier: tzId) {
            dateFormatter.timeZone = tz
        }
        
        var info = dateFormatter.string(from: metadata.birthDate)
        if let place = metadata.birthPlaceInput {
            info += "\n\(place)"
        }
        return info
    }
    
    private func cleanSectionTitle(_ title: String) -> String {
        // Remove any emoji or special characters at the start
        title.trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    NavigationStack {
        // Create mock data for preview
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
            ],
            aspects: nil,
            evolutionaryCore: EvolutionaryCore(
                pluto: nil,
                northNode: PlanetaryPosition(planet: .northNode, longitude: 90, sign: .cancer, degreeInSign: 0, house: 4, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                southNode: PlanetaryPosition(planet: .southNode, longitude: 270, sign: .capricorn, degreeInSign: 0, house: 10, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                moon: nil,
                sun: nil,
                risingSign: .aries,
                notes: []
            )
        )
        
        let mockProfile = UserProfile(
            name: "Alex",
            email: "alex@test.com",
            dateOfBirth: Date(),
            authProvider: "email"
        )
        
        ChartReadingView(chart: mockChart, profile: mockProfile)
    }
}

