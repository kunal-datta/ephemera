//
//  OnboardingView.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

enum OnboardingStep: Int, CaseIterable {
    case name = 0
    case dateOfBirth = 1
    case timeOfBirth = 2
    case placeOfBirth = 3
    
    var title: String {
        switch self {
        case .name: return "what shall we call you?"
        case .dateOfBirth: return "when were you born?"
        case .timeOfBirth: return "what time were you born?"
        case .placeOfBirth: return "where were you born?"
        }
    }
    
    var subtitle: String {
        switch self {
        case .name: return "your name helps us personalize your journey"
        case .dateOfBirth: return "your birth date reveals your celestial blueprint"
        case .timeOfBirth: return "birth time unlocks your rising sign & houses"
        case .placeOfBirth: return "location determines your cosmic coordinates"
        }
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    let email: String
    let authProvider: String
    
    @State private var currentStep: OnboardingStep = .name
    @State private var showContent = false
    
    // Form data
    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var timeOfBirth = Date()
    @State private var timeOfBirthUnknown = false
    @State private var placeOfBirth = ""
    @State private var placeOfBirthUnknown = false
    
    @State private var onboardingComplete = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.04, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            StarFieldView()
                .opacity(0.35)
            
            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(progress: Double(currentStep.rawValue + 1) / Double(OnboardingStep.allCases.count))
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                
                Spacer()
                    .frame(height: 50)
                
                // Step content
                VStack(spacing: 16) {
                    Text(currentStep.title)
                        .font(.custom("Georgia", size: 28))
                        .fontWeight(.light)
                        .tracking(1)
                        .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
                        .multilineTextAlignment(.center)
                        .id(currentStep.title)
                    
                    Text(currentStep.subtitle)
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                        .tracking(0.5)
                        .multilineTextAlignment(.center)
                        .id(currentStep.subtitle)
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 15)
                
                Spacer()
                    .frame(height: 50)
                
                // Dynamic input based on step
                Group {
                    switch currentStep {
                    case .name:
                        NameInputView(name: $name)
                    case .dateOfBirth:
                        DateOfBirthInputView(dateOfBirth: $dateOfBirth)
                    case .timeOfBirth:
                        TimeOfBirthInputView(
                            timeOfBirth: $timeOfBirth,
                            timeUnknown: $timeOfBirthUnknown
                        )
                    case .placeOfBirth:
                        PlaceOfBirthInputView(
                            place: $placeOfBirth,
                            placeUnknown: $placeOfBirthUnknown
                        )
                    }
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: showContent)
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep != .name {
                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                                .frame(width: 54, height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                    
                    Button(action: goNext) {
                        Text(currentStep == .placeOfBirth ? "Begin Journey" : "Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(canProceed ? Color(red: 0.05, green: 0.05, blue: 0.1) : Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(canProceed 
                                          ? Color(red: 0.92, green: 0.88, blue: 0.82)
                                          : Color(red: 0.15, green: 0.15, blue: 0.2))
                            )
                    }
                    .disabled(!canProceed)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $onboardingComplete) {
            HomeView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
        }
        .onChange(of: currentStep) { _, _ in
            showContent = false
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .name:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .dateOfBirth:
            return true
        case .timeOfBirth:
            return true // Can always proceed (unknown is valid)
        case .placeOfBirth:
            return placeOfBirthUnknown || !placeOfBirth.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    private func goBack() {
        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = previousStep
            }
        }
    }
    
    private func goNext() {
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = nextStep
            }
        } else {
            // Complete onboarding
            saveProfile()
        }
    }
    
    private func saveProfile() {
        let profile = UserProfile(
            name: name,
            email: email,
            dateOfBirth: dateOfBirth,
            timeOfBirth: timeOfBirthUnknown ? nil : timeOfBirth,
            timeOfBirthUnknown: timeOfBirthUnknown,
            placeOfBirth: placeOfBirthUnknown ? nil : placeOfBirth,
            placeOfBirthUnknown: placeOfBirthUnknown,
            authProvider: authProvider
        )
        
        // Save to local SwiftData
        modelContext.insert(profile)
        
        // Save to Firestore
        Task {
            do {
                try await FirestoreService.shared.saveUserProfile(profile)
                print("✅ Profile saved to both SwiftData and Firestore")
            } catch {
                print("❌ Failed to save to Firestore: \(error.localizedDescription)")
                // Profile is still saved locally, so we continue
            }
        }
        
        onboardingComplete = true
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.7, green: 0.65, blue: 0.55),
                                Color(red: 0.85, green: 0.8, blue: 0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Name Input
struct NameInputView: View {
    @Binding var name: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NAME")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .tracking(2)
            
            TextField("", text: $name, prompt: Text("Enter your name")
                .foregroundColor(Color.white.opacity(0.25)))
            .font(.system(size: 18))
            .foregroundColor(.white)
            .textContentType(.name)
            .autocorrectionDisabled()
            .focused($isFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused 
                                    ? Color(red: 0.5, green: 0.45, blue: 0.6) 
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}

// MARK: - Date of Birth Input
struct DateOfBirthInputView: View {
    @Binding var dateOfBirth: Date
    
    var body: some View {
        VStack(spacing: 16) {
            DatePicker(
                "",
                selection: $dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
            )
        }
    }
}

// MARK: - Time of Birth Input
struct TimeOfBirthInputView: View {
    @Binding var timeOfBirth: Date
    @Binding var timeUnknown: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if !timeUnknown {
                DatePicker(
                    "",
                    selection: $timeOfBirth,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.25)) {
                    timeUnknown.toggle() 
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: timeUnknown ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(timeUnknown 
                                         ? Color(red: 0.7, green: 0.65, blue: 0.55) 
                                         : Color.white.opacity(0.3))
                    
                    Text("I'll find out later")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(timeUnknown 
                              ? Color(red: 0.12, green: 0.11, blue: 0.16) 
                              : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            
            if timeUnknown {
                Text("You can update this anytime in settings. Some features work best with an accurate birth time.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Place of Birth Input with Autocomplete
struct PlaceOfBirthInputView: View {
    @Binding var place: String
    @Binding var placeUnknown: Bool
    @FocusState private var isFocused: Bool
    
    @StateObject private var placesService = PlacesService.shared
    @State private var searchText = ""
    @State private var showDropdown = false
    @State private var selectedPlace: PlacePrediction?
    
    var body: some View {
        VStack(spacing: 20) {
            if !placeUnknown {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CITY OR TOWN")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                        .tracking(2)
                    
                    // Search field with dropdown
                    VStack(spacing: 0) {
                        // Text field
                        HStack {
                            TextField("", text: $searchText, prompt: Text("Start typing a city...")
                                .foregroundColor(Color.white.opacity(0.25)))
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .focused($isFocused)
                            .onChange(of: searchText) { _, newValue in
                                if selectedPlace == nil || newValue != selectedPlace?.displayText {
                                    placesService.searchPlaces(query: newValue)
                                    showDropdown = !newValue.isEmpty
                                }
                            }
                            
                            // Loading indicator or clear button
                            if placesService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.7, green: 0.65, blue: 0.55)))
                                    .scaleEffect(0.8)
                            } else if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    place = ""
                                    selectedPlace = nil
                                    placesService.clearPredictions()
                                    showDropdown = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.white.opacity(0.3))
                                        .font(.system(size: 18))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: showDropdown && !placesService.predictions.isEmpty ? 12 : 12)
                                .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isFocused 
                                        ? Color(red: 0.5, green: 0.45, blue: 0.6) 
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        
                        // Dropdown with predictions
                        if showDropdown && !placesService.predictions.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(placesService.predictions) { prediction in
                                    Button(action: {
                                        selectPlace(prediction)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(prediction.mainText)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                
                                                if !prediction.secondaryText.isEmpty {
                                                    Text(prediction.secondaryText)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(Color.white.opacity(0.5))
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.clear)
                                    }
                                    .buttonStyle(PlaceRowButtonStyle())
                                    
                                    // Divider between items (except last)
                                    if prediction.id != placesService.predictions.last?.id {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(height: 1)
                                            .padding(.leading, 48)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: showDropdown)
                    .animation(.easeOut(duration: 0.2), value: placesService.predictions)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.25)) {
                    placeUnknown.toggle()
                    if !placeUnknown {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isFocused = true
                        }
                    } else {
                        placesService.clearPredictions()
                        showDropdown = false
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: placeUnknown ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(placeUnknown 
                                         ? Color(red: 0.7, green: 0.65, blue: 0.55) 
                                         : Color.white.opacity(0.3))
                    
                    Text("I'll find out later")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(placeUnknown 
                              ? Color(red: 0.12, green: 0.11, blue: 0.16) 
                              : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            
            if placeUnknown {
                Text("Birth location affects house placements and certain readings. You can add this later.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if !placeUnknown {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
                // If we already have a place selected, show it
                if !place.isEmpty {
                    searchText = place
                }
            }
        }
    }
    
    private func selectPlace(_ prediction: PlacePrediction) {
        selectedPlace = prediction
        searchText = prediction.displayText
        place = prediction.displayText
        showDropdown = false
        placesService.clearPredictions()
        isFocused = false
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Place Row Button Style
struct PlaceRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed 
                    ? Color.white.opacity(0.05) 
                    : Color.clear
            )
    }
}

#Preview {
    NavigationStack {
        OnboardingView(email: "test@example.com", authProvider: "email")
            .modelContainer(for: UserProfile.self, inMemory: true)
    }
}

