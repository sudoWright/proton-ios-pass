//
// WipeAllData.swift
// Proton Pass - Created on 14/11/2023.
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

import Client
import Core
import Foundation
import ProtonCoreFeatureFlags
import UIKit

protocol WipeAllDataUseCase {
    func execute(isTests: Bool) async
}

extension WipeAllDataUseCase {
    func callAsFunction(isTests: Bool) async {
        await execute(isTests: isTests)
    }
}

final class WipeAllData: WipeAllDataUseCase {
    private let logger: Logger
    private let appData: AppDataProtocol
    private let mainKeyProvider: MainKeyProvider
    private let apiManager: APIManager
    private let preferences: Preferences
    private let databaseService: DatabaseServiceProtocol
    private let syncEventLoop: SyncEventLoopProtocol
    private let vaultsManager: VaultsManager
    private let vaultSyncEventStream: VaultSyncEventStream
    private let credentialManager: CredentialManagerProtocol
    private let userDataProvider: UserDataProvider
    private let featureFlagsRepository: FeatureFlagsRepositoryProtocol

    init(logManager: LogManagerProtocol,
         appData: AppDataProtocol,
         mainKeyProvider: MainKeyProvider,
         apiManager: APIManager,
         preferences: Preferences,
         databaseService: DatabaseServiceProtocol,
         syncEventLoop: SyncEventLoopProtocol,
         vaultsManager: VaultsManager,
         vaultSyncEventStream: VaultSyncEventStream,
         credentialManager: CredentialManagerProtocol,
         userDataProvider: UserDataProvider,
         featureFlagsRepository: FeatureFlagsRepositoryProtocol) {
        logger = .init(manager: logManager)
        self.appData = appData
        self.mainKeyProvider = mainKeyProvider
        self.apiManager = apiManager
        self.preferences = preferences
        self.databaseService = databaseService
        self.syncEventLoop = syncEventLoop
        self.vaultsManager = vaultsManager
        self.vaultSyncEventStream = vaultSyncEventStream
        self.credentialManager = credentialManager
        self.userDataProvider = userDataProvider
        self.featureFlagsRepository = featureFlagsRepository
    }

    func execute(isTests: Bool) async {
        logger.info("Wiping all data")

        if let userID = try? userDataProvider.getUserId(), !userID.isEmpty {
            featureFlagsRepository.resetFlags(for: userID)
        }
        featureFlagsRepository.clearUserId()

        appData.resetData()
        mainKeyProvider.wipeMainKey()
        apiManager.clearCredentials()
        await preferences.reset(isTests: isTests)
        databaseService.resetContainer()
        UIPasteboard.general.items = []
        syncEventLoop.reset()
        await vaultsManager.reset()
        vaultSyncEventStream.value = .initialization
        try? await credentialManager.removeAllCredentials()
        logger.info("Wiped all data")
    }
}
