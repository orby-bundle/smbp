//
//  AuthAppleCoordinator.swift
//  Baza Prawna
//
//  Created by Anton Shablyka on 08/10/2025.
//

import Foundation
import AuthenticationServices
import FirebaseAuth
import CryptoKit
import Combine
import SwiftUI

@MainActor
class SignInWithAppleCoordinator: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isSigningIn = false
    @Published var errorMessage: String?
    
    private var currentNonce: String?
    private let authManager = AuthenticationManager.shared
    
    // MARK: - Programmatic Sign In
    
    func triggerSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        configure(request: request)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - SignInWithAppleButton View
    
    var signInWithAppleButton: some View {
        SignInWithAppleButton(
            onRequest: { request in
                self.configure(request: request)
            },
            onCompletion: { result in
                self.handleAppleSignInResult(result)
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .disabled(isSigningIn)
        .opacity(isSigningIn ? 0.7 : 1.0)
        .overlay(
            Group {
                if isSigningIn {
                    ZStack {
                        // Semi-transparent background to hide button text
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                            .frame(height: 50)
                        
                        // Loading indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                }
            }
        )
        .animation(.easeInOut(duration: 0.2), value: isSigningIn)
    }
    
    // MARK: - Private Methods
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            processAuthorization(authorization)
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func processAuthorization(_ authorization: ASAuthorization) {
        isSigningIn = true
        errorMessage = nil
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Invalid Apple ID credential"
            isSigningIn = false
            return
        }
        
        guard let nonce = currentNonce else {
            errorMessage = "Missing login state. Please try again."
            isSigningIn = false
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            errorMessage = "Unable to fetch identity token"
            isSigningIn = false
            currentNonce = nil
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to serialize token string from data"
            isSigningIn = false
            currentNonce = nil
            return
        }
        
        // Create Firebase credential
        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        // Sign in with Apple ID credential
        Task {
            defer { self.currentNonce = nil }
            do {
                try await authManager.signInWithAppleID(credential: credential)
                print("OK: Successfully signed in with Apple ID")
                
                isSigningIn = false
            } catch {
                print("WARN: Apple ID sign-in failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isSigningIn = false
            }
        }
    }
    
    private func configure(request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = authManager.generateNonce()
        currentNonce = nonce
        request.nonce = authManager.sha256(nonce)
    }

    private func handleError(_ error: Error) {
        print("WARN: Apple ID authorization failed: \(error.localizedDescription)")
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = "Sign in was canceled"
            case .failed:
                errorMessage = "Sign in failed"
            case .invalidResponse:
                errorMessage = "Invalid response from Apple"
            case .notHandled:
                errorMessage = "Sign in request was not handled"
            case .unknown:
                errorMessage = "Unknown error occurred"
            case .notInteractive:
                errorMessage = "Sign in request was not interactive"
            case .matchedExcludedCredential:
                errorMessage = "Matched excluded credential"
            case .credentialImport:
                errorMessage = "Credential import"
            case .credentialExport:
                errorMessage = "Credential export"
            case .preferSignInWithApple:
                errorMessage = "Prefer sign in with Apple"
            case .deviceNotConfiguredForPasskeyCreation:
                errorMessage = "Device not configured for passkey creation"
            @unknown default:
                errorMessage = "Unknown error occurred"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        isSigningIn = false
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleAppleSignInResult(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        handleAppleSignInResult(.failure(error))
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}
