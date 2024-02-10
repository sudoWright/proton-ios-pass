//
//
// SetShareInviteVault.swift
// Proton Pass - Created on 20/07/2023.
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

import Client
import Entities

public protocol SetShareInviteVaultUseCase {
    func execute(with vault: SharingVaultData)
}

public extension SetShareInviteVaultUseCase {
    func callAsFunction(with vault: SharingVaultData) {
        execute(with: vault)
    }
}

public final class SetShareInviteVault: SetShareInviteVaultUseCase {
    private let shareInviteService: any ShareInviteServiceProtocol
    private let getVaultItemCount: any GetVaultItemCountUseCase

    public init(shareInviteService: any ShareInviteServiceProtocol,
                getVaultItemCount: any GetVaultItemCountUseCase) {
        self.shareInviteService = shareInviteService
        self.getVaultItemCount = getVaultItemCount
    }

    public func execute(with vault: SharingVaultData) {
        shareInviteService.currentSelectedVault.send(vault)
        switch vault {
        case let .existing(createdVault):
            shareInviteService.setCurrentSelectedVaultItem(with: getVaultItemCount(for: createdVault))
        case .new:
            shareInviteService.setCurrentSelectedVaultItem(with: 1)
        }
    }
}
