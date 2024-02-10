//
// LimitedVaultOperationsBanner.swift
// Proton Pass - Created on 24/05/2023.
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

import DesignSystem
import SwiftUI

struct LimitedVaultOperationsBanner: View {
    let onUpgrade: () -> Void

    var body: some View {
        texts
            .padding()
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(uiColor: PassColor.interactionNormMinor1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture(perform: onUpgrade)
    }

    private var texts: some View {
        Text("To interact with your other vaults, you need to upgrade your account.")
            .foregroundColor(Color(uiColor: PassColor.textNorm)) +
            Text(verbatim: " ") +
            Text("Upgrade now")
            .underline(color: Color(uiColor: PassColor.interactionNormMajor1))
            .foregroundColor(Color(uiColor: PassColor.interactionNormMajor1))
    }
}
