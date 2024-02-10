//
// LocalAuthenticationView.swift
// Proton Pass - Created on 22/06/2023.
// Copyright (c) 2023 Proton Technologies AG
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
import Factory
import ProtonCoreUIFoundations
import SwiftUI

/// Not to be used directly but via `localAuthentication` view modifier
struct LocalAuthenticationView: View {
    @StateObject private var viewModel: LocalAuthenticationViewModel
    private let preferences = resolve(\SharedToolingContainer.preferences)

    init(mode: LocalAuthenticationViewModel.Mode,
         delayed: Bool,
         onAuth: @escaping () -> Void,
         onSuccess: @escaping () -> Void,
         onFailure: @escaping () -> Void) {
        _viewModel = .init(wrappedValue: .init(mode: mode,
                                               delayed: delayed,
                                               onAuth: onAuth,
                                               onSuccess: onSuccess,
                                               onFailure: onFailure))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PassColor.backgroundNorm.toColor
                .ignoresSafeArea()

            switch viewModel.mode {
            case .biometric:
                BiometricAuthenticationView(viewModel: viewModel)
            case .pin:
                PinAuthenticationView(viewModel: viewModel)
            }

            Button { viewModel.logOut() } label: {
                Image(uiImage: IconProvider.arrowOutFromRectangle)
                    .foregroundColor(PassColor.textNorm.toColor)
                    .padding()
            }
            .padding()
        }
        .theme(preferences.theme)
    }
}
