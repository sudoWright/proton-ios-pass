//
// PinAuthenticationView.swift
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
import Macro
import SwiftUI

struct PinAuthenticationView: View {
    @ObservedObject private var viewModel: LocalAuthenticationViewModel
    @FocusState private var isFocused
    @State private var pinCode = ""
    private let module = resolve(\SharedToolingContainer.module)

    init(viewModel: LocalAuthenticationViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .center) {
            Image(uiImage: PassIcon.passIcon)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 160)

            Text("Enter your PIN code")
                .foregroundColor(PassColor.textNorm.toColor)
                .font(.title.bold())

            Spacer()

            SecureField("PIN Code", text: $pinCode)
                .labelsHidden()
                .foregroundColor(PassColor.textNorm.toColor)
                .font(.title.bold())
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)

            Spacer()

            switch viewModel.state {
            case .noAttempts:
                EmptyView()
            case let .remainingAttempts(count):
                Text("Incorrect PIN code.")
                    .foregroundColor(PassColor.signalDanger.toColor) +
                    Text(verbatim: " ") +
                    Text("\(count) remaining attempt(s)")
                    .foregroundColor(PassColor.signalDanger.toColor)
            case .lastAttempt:
                Text("This is your last attempt. You will be logged out after failing to authenticate again.")
                    .foregroundColor(PassColor.signalDanger.toColor)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            DisablableCapsuleTextButton(title: #localized("Unlock"),
                                        titleColor: PassColor.textInvert,
                                        disableTitleColor: PassColor.textInvert,
                                        backgroundColor: PassColor.interactionNormMajor1,
                                        disableBackgroundColor: PassColor.interactionNormMajor1
                                            .withAlphaComponent(0.3),
                                        disabled: pinCode.count < Constants.PINCode.minLength,
                                        height: 60,
                                        action: { viewModel.checkPinCode(pinCode) })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accentColor(PassColor.interactionNorm.toColor)
        .tint(PassColor.interactionNorm.toColor)
        .animation(.default, value: viewModel.state)
        .onChange(of: viewModel.state) { _ in
            pinCode = ""
        }
        .onAppear {
            let notifyAuthProcessAndFocus: () -> Void = {
                viewModel.onAuth()
                isFocused = true
            }
            // Delay keyboard appearance when in extension context because
            // it takes longer for the view to be rendered
            if module == .hostApp {
                notifyAuthProcessAndFocus()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    notifyAuthProcessAndFocus()
                }
            }
        }
    }
}
