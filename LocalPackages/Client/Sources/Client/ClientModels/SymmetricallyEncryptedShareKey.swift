//
// SymmetricallyEncryptedShareKey.swift
// Proton Pass - Created on 10/04/2023.
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

import Entities
import Foundation

/// `ShareKey` with its symmetrically encrypted key by an application-wide symmetric key
public struct SymmetricallyEncryptedShareKey: Hashable, Sendable {
    /// Base64 representation of the symmetrically encrypted share key
    public let encryptedKey: String

    /// ID of the share that the key belongs to
    public let shareId: String

    /// Original `ShareKey` object as returned by the server
    public let shareKey: ShareKey
}

public extension [SymmetricallyEncryptedShareKey] {
    func latestKey() throws -> SymmetricallyEncryptedShareKey {
        guard !isEmpty else {
            throw PassError.crypto(.missingKeys)
        }

        guard let latestKey =
            sorted(by: { $0.shareKey.keyRotation < $1.shareKey.keyRotation }).last else {
            throw PassError.crypto(.missingKeys)
        }
        return latestKey
    }
}
