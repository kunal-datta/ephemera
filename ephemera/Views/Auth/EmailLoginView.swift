//
//  EmailLoginView.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI

struct EmailLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showOnboarding = false
    @State private var showContent = false
    @FocusState private var isEmailFocused: Bool
    
    private var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
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
            
            // Subtle star field
            StarFieldView()
                .opacity(0.4)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Header
                VStack(spacing: 12) {
                    Text("welcome")
                        .font(.custom("Georgia", size: 36))
                        .fontWeight(.light)
                        .tracking(4)
                        .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 15)
                    
                    Text("enter your email to begin")
                        .font(.custom("Georgia", size: 15))
                        .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                        .tracking(1)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
                }
                
                Spacer()
                    .frame(height: 80)
                
                // Email input
                VStack(alignment: .leading, spacing: 8) {
                    Text("EMAIL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                        .tracking(2)
                    
                    TextField("", text: $email, prompt: Text("you@example.com")
                        .foregroundColor(Color.white.opacity(0.25)))
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isEmailFocused 
                                            ? Color(red: 0.5, green: 0.45, blue: 0.6) 
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .animation(.easeOut(duration: 0.2), value: isEmailFocused)
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
                
                Spacer()
                
                // Continue button
                VStack(spacing: 16) {
                    Button(action: handleContinue) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isValidEmail ? Color(red: 0.05, green: 0.05, blue: 0.1) : Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isValidEmail 
                                          ? Color(red: 0.92, green: 0.88, blue: 0.82)
                                          : Color(red: 0.15, green: 0.15, blue: 0.2))
                            )
                    }
                    .disabled(!isValidEmail)
                    .animation(.easeOut(duration: 0.2), value: isValidEmail)
                    
                    Text("We'll send you updates about your cosmic journey")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
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
        }
        .navigationDestination(isPresented: $showOnboarding) {
            OnboardingView(email: email, authProvider: "email")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isEmailFocused = true
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func handleContinue() {
        guard isValidEmail else { return }
        showOnboarding = true
    }
}

#Preview {
    NavigationStack {
        EmailLoginView()
    }
}

