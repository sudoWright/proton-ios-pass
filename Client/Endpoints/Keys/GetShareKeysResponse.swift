//
// GetShareKeysResponse.swift
// Proton Pass - Created on 13/08/2022.
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

import Foundation

public struct GetShareKeysResponse: Decodable {
    let code: Int
    let keys: ShareKeysResponse
}

public struct ShareKeysResponse: Decodable {
    public let vaultKeys: [VaultKey]
    public let itemKeys: [ItemKey]
    public let total: Int

    init(vaultKeys: [VaultKey], itemKeys: [ItemKey], total: Int) {
        self.vaultKeys = vaultKeys
        self.itemKeys = itemKeys
        self.total = total
    }

    public var isEmpty: Bool { vaultKeys.isEmpty || itemKeys.isEmpty }
}
