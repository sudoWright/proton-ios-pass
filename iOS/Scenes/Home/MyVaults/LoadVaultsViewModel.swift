//
// LoadVaultsViewModel.swift
// Proton Pass - Created on 21/07/2022.
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

import Client
import Core
import ProtonCore_Login

final class LoadVaultsViewModel: DeinitPrintable, ObservableObject {
    deinit { print(deinitMessage) }

    @Published private(set) var error: Error?

    private let userData: UserData
    private let vaultSelection: VaultSelection
    private let shareRepository: ShareRepositoryProtocol
    private let logger: Logger

    var onToggleSidebar: (() -> Void)?

    init(userData: UserData,
         vaultSelection: VaultSelection,
         shareRepository: ShareRepositoryProtocol,
         logManager: LogManager) {
        self.userData = userData
        self.vaultSelection = vaultSelection
        self.shareRepository = shareRepository
        self.logger = .init(subsystem: Bundle.main.bundleIdentifier ?? "",
                            category: "\(Self.self)",
                            manager: logManager)
    }

    func fetchVaults(forceRefresh: Bool) {
        Task { @MainActor in
            do {
                error = nil
                let vaults = try await self.fetchVaultsTask(forceRefresh: forceRefresh).value
                if vaults.isEmpty {
                    try await createDefaultVaultTask.value
                    fetchVaults(forceRefresh: false)
                } else {
                    vaultSelection.update(vaults: vaults)
                }
            } catch {
                logger.error(error)
                self.error = error
            }
        }
    }

    private var createDefaultVaultTask: Task<Void, Error> {
        Task.detached(priority: .userInitiated) {
            let addressKey = try self.userData.getAddressKey()
            let createVaultRequest = try CreateVaultRequest(addressKey: addressKey,
                                                            name: "Personal",
                                                            description: "Personal vault")
            try await self.shareRepository.createVault(request: createVaultRequest)
        }
    }

    private func fetchVaultsTask(forceRefresh: Bool) -> Task<[VaultProtocol], Error> {
        Task.detached(priority: .userInitiated) {
            try await self.shareRepository.getVaults(forceRefresh: forceRefresh)
        }
    }
}
