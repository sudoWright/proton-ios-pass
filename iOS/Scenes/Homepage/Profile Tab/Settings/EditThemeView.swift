//
// EditThemeView.swift
// Proton Pass - Created on 31/03/2023.
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
import SwiftUI

struct EditThemeView: View {
    @Environment(\.dismiss) private var dismiss
    let preferences: Preferences

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Theme.allCases, id: \.rawValue) { theme in
                        SelectableOptionRow(action: { preferences.theme = theme; dismiss() },
                                            height: .short,
                                            content: {
                                                Label(title: {
                                                    Text(theme.description)
                                                }, icon: {
                                                    Image(uiImage: theme.icon)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(maxWidth: 20, maxHeight: 20)
                                                })
                                                .foregroundColor(Color(uiColor: PassColor.textNorm))
                                            },
                                            isSelected: theme == preferences.theme)

                        PassDivider()
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: PassColor.backgroundWeak))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Theme")
                        .navigationTitleText()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
