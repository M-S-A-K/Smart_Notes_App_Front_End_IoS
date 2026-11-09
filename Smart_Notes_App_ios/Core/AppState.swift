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
    @Published var appLockPin: String = UserDefaults.standard.string(forKey: "appLockPin") ?? "" {
        didSet { UserDefaults.standard.set(appLockPin, forKey: "appLockPin") }
    }
    @Published var darkMode = UserDefaults.standard.bool(forKey: "darkMode") {
        didSet { UserDefaults.standard.set(darkMode, forKey: "darkMode") }
    }
    @Published var locked = false
    @Published var unlockError = ""

    init() {
        if let data = UserDefaults.standard.data(forKey: "user"),
           let saved = try? JSONDecoder().decode(AuthUser.self, from: data) {
            setUser(saved)
        }
        locked = appLock && !appLockPin.isEmpty && user != nil
        ReminderAlarmManager.shared.requestPermission()
    }

    func login(email: String, password: String) async throws {
        setUser(try await API.shared.login(email: email, password: password))
    }

    func register(name: String, email: String, password: String) async throws {
        setUser(try await API.shared.register(name: name, email: email, password: password))
    }

    func logout() {
        user = nil
        locked = false
        API.shared.userId = nil
        UserDefaults.standard.removeObject(forKey: "user")
    }

    func setUser(_ u: AuthUser) {
        user = u
        API.shared.userId = u.userId
        UserDefaults.standard.set(try? JSONEncoder().encode(u), forKey: "user")
    }

    func verifyPin(_ input: String) -> Bool {
        guard !appLockPin.isEmpty, input == appLockPin else {
            unlockError = "Incorrect passcode. Please try again."
            return false
        }
        unlockError = ""
        locked = false
        return true
    }

    // Uses ONLY real Face ID / Touch ID (does not allow Simulator's any-number fallback)
    func unlockWithFaceID() async {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return
        }
        if (try? await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock Smart Notes with Face ID"
        )) == true {
            unlockError = ""
            locked = false
        }
    }
}
