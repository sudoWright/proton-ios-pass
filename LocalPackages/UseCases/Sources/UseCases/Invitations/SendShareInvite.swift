//
//
// SendShareInvite.swift
// Proton Pass - Created on 21/07/2023.
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
import Core
import CryptoKit
import Entities
import ProtonCoreCrypto
import ProtonCoreLogin

/// Make an invitation and return the shared `Vault`
public protocol SendVaultShareInviteUseCase: Sendable {
    func execute(with infos: [SharingInfos]) async throws -> Vault
}

public extension SendVaultShareInviteUseCase {
    func callAsFunction(with infos: [SharingInfos]) async throws -> Vault {
        try await execute(with: infos)
    }
}

public final class SendVaultShareInvite: @unchecked Sendable, SendVaultShareInviteUseCase {
    private let createAndMoveItemToNewVault: any CreateAndMoveItemToNewVaultUseCase
    private let makeUnsignedSignatureForVaultSharing: any MakeUnsignedSignatureForVaultSharingUseCase
    private let shareInviteService: any ShareInviteServiceProtocol
    private let passKeyManager: any PassKeyManagerProtocol
    private let shareInviteRepository: any ShareInviteRepositoryProtocol
    private let userDataProvider: any UserDataProvider
    private let syncEventLoop: any SyncEventLoopProtocol

    public init(createAndMoveItemToNewVault: any CreateAndMoveItemToNewVaultUseCase,
                makeUnsignedSignatureForVaultSharing: any MakeUnsignedSignatureForVaultSharingUseCase,
                shareInviteService: any ShareInviteServiceProtocol,
                passKeyManager: any PassKeyManagerProtocol,
                shareInviteRepository: any ShareInviteRepositoryProtocol,
                userDataProvider: any UserDataProvider,
                syncEventLoop: any SyncEventLoopProtocol) {
        self.createAndMoveItemToNewVault = createAndMoveItemToNewVault
        self.makeUnsignedSignatureForVaultSharing = makeUnsignedSignatureForVaultSharing
        self.shareInviteService = shareInviteService
        self.passKeyManager = passKeyManager
        self.shareInviteRepository = shareInviteRepository
        self.userDataProvider = userDataProvider
        self.syncEventLoop = syncEventLoop
    }

    public func execute(with infos: [SharingInfos]) async throws -> Vault {
        guard let baseInfo = infos.first else {
            throw PassError.sharing(.incompleteInformation)
        }
        let vault = try await getVault(from: baseInfo)
        let vaultKey = try await passKeyManager.getLatestShareKey(shareId: vault.shareId)
        let inviteesData = try infos.map { try generateInviteeData(from: $0, vault: vault, vaultKey: vaultKey) }
        let invited = try await shareInviteRepository.sendInvites(shareId: vault.shareId,
                                                                  inviteesData: inviteesData,
                                                                  targetType: .vault)

        if invited {
            syncEventLoop.forceSync()
            shareInviteService.resetShareInviteInformations()
            return vault
        }

        throw PassError.sharing(.failedToInvite)
    }
}

private extension SendVaultShareInvite {
    func getVault(from info: SharingInfos) async throws -> Vault {
        switch info.vault {
        case let .existing(vault):
            vault
        case let .new(vaultProtobuf, itemContent):
            try await createAndMoveItemToNewVault(vault: vaultProtobuf, itemContent: itemContent)
        }
    }

    func generateInviteeData(from info: SharingInfos,
                             vault: Vault,
                             vaultKey: DecryptedShareKey) throws -> InviteeData {
        let userData = try userDataProvider.getUnwrappedUserData()
        let email = info.email
        if let key = info.receiverPublicKeys?.first {
            let signedKey = try CryptoUtils.encryptKeyForSharing(addressId: vault.addressId,
                                                                 publicReceiverKey: key,
                                                                 userData: userData,
                                                                 vaultKey: vaultKey)
            return .existing(email: email, keys: [signedKey], role: info.role)
        } else {
            let signature = try createAndSignSignature(addressId: vault.addressId,
                                                       vaultKey: vaultKey,
                                                       email: email,
                                                       userData: userData)
            return .new(email: email, signature: signature, role: info.role)
        }
    }

    func createAndSignSignature(addressId: String,
                                vaultKey: DecryptedShareKey,
                                email: String,
                                userData: UserData) throws -> String {
        guard let addressKey = try CryptoUtils.unlockAddressKeys(addressID: addressId,
                                                                 userData: userData).first else {
            throw PassError.crypto(.addressNotFound(addressID: addressId))
        }

        let signerKey = SigningKey(privateKey: addressKey.privateKey,
                                   passphrase: addressKey.passphrase)
        let unsignedSignature = makeUnsignedSignatureForVaultSharing(email: email,
                                                                     vaultKey: vaultKey.keyData)
        let context = SignatureContext(value: Constants.newUserSharingSignatureContext,
                                       isCritical: true)

        return try Sign.signDetached(signingKey: signerKey,
                                     plainData: unsignedSignature,
                                     signatureContext: context)
            .unArmor().value.base64EncodedString()
    }
}
