//
// AppState.swift
// Proton Pass - Created on 21/06/2022.
// Copyright (c) 2022 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import ProtonCoreLogin
import SwiftUI

public enum LogOutReason {
    case noSessionDataAtAll
    case noAuthSessionButUnauthSessionAvailable
    case expiredRefreshToken
    case failedToGenerateSymmetricKey
    case failedBiometricAuthentication
    case sessionInvalidated
    case userInitiated
}

public enum AppState {
    case loggedOut(LogOutReason)
    case manuallyLoggedIn(UserData)
    case alreadyLoggedIn
    case undefined
}

/// This class is meant to observe the user state changes.
public class AppStateObserver: ObservableObject {
    @Published public private(set) var appState: AppState = .undefined

    public init() {}

    public func updateAppState(_ appState: AppState) {
        self.appState = appState
    }
}
