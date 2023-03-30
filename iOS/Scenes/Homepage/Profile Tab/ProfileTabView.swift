//
// ProfileTabView.swift
// Proton Pass - Created on 07/03/2023.
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

import SwiftUI
import UIComponents

struct ProfileTabView: View {
    @StateObject var viewModel: ProfileTabViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Profile")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView {
                VStack {
                    itemCountSection
                        .padding(.bottom)
                    biometricAuthenticationSection
                    accountAndSettingsSection
                        .padding(.vertical)
                    Spacer()
                }
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.passBackground)
    }

    private var itemCountSection: some View {
        VStack {
            Text("Items")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            ItemCountView(viewModel: viewModel.itemCountViewModel)
        }
    }

    private var biometricAuthenticationSection: some View {
        VStack {
            Text("Manage my profile")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                switch viewModel.biometricAuthenticator.biometryTypeState {
                case .idle, .initializing:
                    ProgressView()
                case .initialized(let biometryType):
                    if let uiModel = biometryType.uiModel {
                        Toggle(isOn: $viewModel.biometricAuthenticator.enabled) {
                            Label(title: {
                                Text(uiModel.title)
                            }, icon: {
                                if let icon = uiModel.icon {
                                    Image(systemName: icon)
                                        .foregroundColor(.passBrand)
                                } else {
                                    EmptyView()
                                }
                            })
                        }
                        .tint(.passBrand)
                    } else {
                        Text("Biometric authentication not supported")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .error(let error):
                    Text(error.localizedDescription)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .roundedEditableSection()

            if case .initialized(let biometryType) = viewModel.biometricAuthenticator.biometryTypeState,
               biometryType != .none {
                Text("Unlock Proton Pass with a glance.")
                    .font(.callout)
                    .foregroundColor(.textHint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }

    private var accountAndSettingsSection: some View {
        VStack(spacing: 0) {
            Button(action: viewModel.showAccountMenu) {
                HStack {
                    Text("Account")
                    Spacer()
                    ChevronRight()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(kItemDetailSectionPadding)

            PassDivider()

            Button(action: viewModel.showSettingsMenu) {
                HStack {
                    Text("Settings")
                    Spacer()
                    ChevronRight()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(kItemDetailSectionPadding)
        }
        .roundedEditableSection()
        .padding(.horizontal)
    }
}

struct ChevronRight: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .resizable()
            .scaledToFit()
            .frame(height: 12)
            .foregroundColor(Color(.tertiaryLabel))
    }
}
