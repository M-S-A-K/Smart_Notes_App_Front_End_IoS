//
//  AppState.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI
import Combine
import LocalAuthentication

@MainActor
final class AppState: ObservableObject {
    @Published var user: AuthUser?
    @Published var appLock = UserDefaults.standard.bool(forKey: "appLock") {
        didSet { UserDefaults.standard.set(appLock, forKey: "appLock") }
    }
    @Published var locked = false


    init() {
        // Restore the saved login
        if let data = UserDefaults.standard.data(forKey: "user"),
           let saved = try? JSONDecoder().decode(AuthUser.self, from: data) {
            setUser(saved)
        }
        locked = appLock && user != nil
    }

    func login(email: String, password: String) async throws {
        setUser(try await API.shared.login(email: email, password: password))
    }

    func register(name: String, email: String, password: String) async throws {
        setUser(try await API.shared.register(name: name, email: email, password: password))
    }

    func logout() {
        user = nil
        API.shared.userId = nil
        UserDefaults.standard.removeObject(forKey: "user")
    }

    func setUser(_ u: AuthUser) {
        user = u
        API.shared.userId = u.userId
        UserDefaults.standard.set(try? JSONEncoder().encode(u), forKey: "user")
    }
    
    func unlockApp() async {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        if (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Smart Notes")) == true {
            locked = false
        }
    }
    
}
