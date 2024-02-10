//
// CanEditItem.swift
// Proton Pass - Created on 08/12/2023.
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
//

import Entities
import Foundation

public protocol CanEditItemUseCase: Sendable {
    func execute(vaults: [Vault], item: any ItemIdentifiable) -> Bool
}

public extension CanEditItemUseCase {
    func callAsFunction(vaults: [Vault], item: any ItemIdentifiable) -> Bool {
        execute(vaults: vaults, item: item)
    }
}

public final class CanEditItem: CanEditItemUseCase {
    public init() {}

    public func execute(vaults: [Vault], item: any ItemIdentifiable) -> Bool {
        let editableSharedIds = vaults.filter(\.canEdit).map(\.shareId)
        return editableSharedIds.contains { $0 == item.shareId }
    }
}
