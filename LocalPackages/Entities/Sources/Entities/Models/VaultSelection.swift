//
// VaultSelection.swift
// Proton Pass - Created on 30/11/2023.
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

import Foundation

public enum VaultSelection: Hashable, Sendable {
    case all
    case precise(Vault)
    case trash

    public var shared: Bool {
        if case let .precise(vault) = self {
            return vault.shared
        }
        return false
    }

    public var preciseVault: Vault? {
        if case let .precise(vault) = self {
            return vault
        }
        return nil
    }

    public var showBadge: Bool {
        if case let .precise(vault) = self {
            vault.newUserInvitesReady > 0
        } else {
            false
        }
    }
}

extension VaultSelection: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.trash, .trash):
            true
        case let (.precise(lhsVault), .precise(rhsVault)):
            lhsVault.id == rhsVault.id && lhsVault.shareId == rhsVault.shareId
        default:
            false
        }
    }
}
