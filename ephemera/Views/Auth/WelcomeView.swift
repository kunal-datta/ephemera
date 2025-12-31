//
//  WelcomeView.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import FirebaseAuth

struct WelcomeView: View {
    @State private var showEmailLogin = false
    @State private var animateStars = false
    @State private var showContent = false
    @State private var showOnboarding = false
    @State private var googleEmail: String = ""
    @State private var isSigningIn = false
    @State private var signInError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient - deep celestial
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
                
                // Subtle star particles
                StarFieldView()
                    .opacity(animateStars ? 0.6 : 0.3)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateStars)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // App name and tagline
                    VStack(spacing: 16) {
                        Text("ephemera")
                            .font(.custom("Georgia", size: 48))
                            .fontWeight(.light)
                            .tracking(6)
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
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        
                        Text("illuminate your soul's journey")
                            .font(.custom("Georgia", size: 15))
                            .fontWeight(.regular)
                            .italic()
                            .foregroundColor(Color(red: 0.65, green: 0.62, blue: 0.58))
                            .tracking(1.5)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 15)
                            .animation(.easeOut(duration: 0.8).delay(0.3), value: showContent)
                    }
                    
                    Spacer()
                    Spacer()
                    
                    // Login buttons
                    VStack(spacing: 16) {
                        // Google Sign In
                        Button(action: handleGoogleSignIn) {
                            HStack(spacing: 12) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20))
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.22))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: showContent)
                        
                        // Email Sign In
                        NavigationLink(destination: EmailLoginView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18))
                                Text("Continue with Email")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(Color(red: 0.85, green: 0.82, blue: 0.78))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.3, green: 0.28, blue: 0.35), lineWidth: 1)
                            )
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
                        
                        // Divider with text
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                            Text("your cosmic journey begins")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.3))
                                .fixedSize()
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                        }
                        .padding(.top, 8)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.7), value: showContent)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
            .navigationDestination(isPresented: $showOnboarding) {
                OnboardingView(email: googleEmail, authProvider: "google")
            }
        }
        .onAppear {
            animateStars = true
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func handleGoogleSignIn() {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInError = nil
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Google Sign-In: Could not find root view controller")
            isSigningIn = false
            signInError = "Could not find root view controller"
            return
        }
        
        print("🔄 Starting Google Sign-In...")
        
        // Start Google Sign-In flow
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            isSigningIn = false
            
            if let error = error {
                print("❌ Google Sign-In error: \(error.localizedDescription)")
                signInError = error.localizedDescription
                return
            }
            
            guard let result = signInResult else {
                print("❌ Google Sign-In: No result returned")
                signInError = "No sign-in result"
                return
            }
            
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                print("❌ Google Sign-In: No ID token")
                signInError = "No ID token"
                return
            }
            
            print("✅ Google Sign-In successful for: \(user.profile?.email ?? "unknown")")
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            // Sign in to Firebase with Google credential
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("❌ Firebase auth error: \(error.localizedDescription)")
                    signInError = error.localizedDescription
                    return
                }
                
                print("✅ Firebase auth successful for: \(authResult?.user.email ?? "unknown")")
                
                // Store email and navigate to onboarding
                if let email = authResult?.user.email {
                    googleEmail = email
                    showOnboarding = true
                }
            }
        }
    }
}

// MARK: - Star Field Background
struct StarFieldView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<50, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: starSize(for: index), height: starSize(for: index))
                        .position(
                            x: starX(for: index, in: geometry.size.width),
                            y: starY(for: index, in: geometry.size.height)
                        )
                        .opacity(starOpacity(for: index))
                }
            }
        }
    }
    
    private func starSize(for index: Int) -> CGFloat {
        let sizes: [CGFloat] = [1, 1.5, 2, 1, 2.5, 1, 1.5, 2, 1, 3]
        return sizes[index % sizes.count]
    }
    
    private func starX(for index: Int, in width: CGFloat) -> CGFloat {
        let seed = Double(index * 127 + 43)
        return CGFloat((sin(seed) + 1) / 2) * width
    }
    
    private func starY(for index: Int, in height: CGFloat) -> CGFloat {
        let seed = Double(index * 89 + 17)
        return CGFloat((cos(seed) + 1) / 2) * height
    }
    
    private func starOpacity(for index: Int) -> Double {
        let opacities: [Double] = [0.3, 0.5, 0.7, 0.4, 0.6, 0.35, 0.55, 0.45, 0.65, 0.5]
        return opacities[index % opacities.count]
    }
}

#Preview {
    WelcomeView()
}

