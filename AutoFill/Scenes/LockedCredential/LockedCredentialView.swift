//
// LockedCredentialView.swift
// Proton Pass - Created on 25/10/2022.
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

import Core
import DesignSystem
import ProtonCoreUIFoundations
import SwiftUI

/// When autofilling from QuickType bar but local authentication is turned on
struct LockedCredentialView: View {
    let preferences: Preferences
    let viewModel: LockedCredentialViewModel

    init(preferences: Preferences, viewModel: LockedCredentialViewModel) {
        self.preferences = preferences
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            PassColor.backgroundNorm.toColor
                .localAuthentication(delayed: true,
                                     onAuth: {},
                                     onSuccess: { viewModel.getAndReturnCredential() },
                                     onFailure: { viewModel.handleAuthenticationFailure() })
                .toolbar { toolbarContent }
        }
        .navigationViewStyle(.stack)
        .theme(preferences.theme)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CircleButton(icon: IconProvider.cross,
                         iconColor: PassColor.interactionNormMajor2,
                         backgroundColor: PassColor.interactionNormMinor1,
                         action: {
                             Task {
                                 await viewModel.handleCancellation()
                             }
                         })
        }
    }
}
