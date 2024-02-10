//
//
// ManageSharedVaultViewModel.swift
// Proton Pass - Created on 02/08/2023.
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
import Combine
import Entities
import Factory
import Foundation
import Macro
import ProtonCoreNetworking

@MainActor
final class ManageSharedVaultViewModel: ObservableObject, @unchecked Sendable {
    private(set) var vault: Vault
    @Published private(set) var itemsNumber = 0
    @Published private(set) var invitations = ShareInvites.default
    @Published private(set) var members: [UserShareInfos] = []
    @Published private(set) var fetching = false
    @Published private(set) var loading = false
    @Published private(set) var isFreeUser = true
    @Published var newOwner: NewOwner?

    private let getVaultItemCount = resolve(\UseCasesContainer.getVaultItemCount)
    private let getUsersLinkedToShare = resolve(\UseCasesContainer.getUsersLinkedToShare)
    private let getPendingInvitationsForShare = resolve(\UseCasesContainer.getPendingInvitationsForShare)
    private let setShareInviteVault = resolve(\UseCasesContainer.setShareInviteVault)
    private let revokeInvitation = resolve(\UseCasesContainer.revokeInvitation)
    private let revokeNewUserInvitation = resolve(\UseCasesContainer.revokeNewUserInvitation)
    private let sendInviteReminder = resolve(\UseCasesContainer.sendInviteReminder)
    private let updateUserShareRole = resolve(\UseCasesContainer.updateUserShareRole)
    private let revokeUserShareAccess = resolve(\UseCasesContainer.revokeUserShareAccess)
    private let transferVaultOwnership = resolve(\UseCasesContainer.transferVaultOwnership)
    private let canUserTransferVaultOwnership = resolve(\UseCasesContainer.canUserTransferVaultOwnership)
    private let promoteNewUserInvite = resolve(\UseCasesContainer.promoteNewUserInvite)
    private let userDataProvider = resolve(\SharedDataContainer.userDataProvider)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let syncEventLoop = resolve(\SharedServiceContainer.syncEventLoop)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let accessRepository = resolve(\SharedRepositoryContainer.accessRepository)
    private var fetchingTask: Task<Void, Never>?

    var reachedLimit: Bool {
        numberOfInvitesLeft <= 0
    }

    var isViewOnly: Bool {
        !vault.isAdmin
    }

    var numberOfInvitesLeft: Int {
        max(vault.maxMembers - (members.count + invitations.totalNumberOfInvites), 0)
    }

    var showInvitesLeft: Bool {
        guard !fetching else {
            return false
        }
        if isFreeUser {
            return !reachedLimit
        } else {
            return reachedLimit
        }
    }

    var showVaultLimitMessage: Bool {
        guard !fetching, isFreeUser else {
            return false
        }

        return reachedLimit
    }

    init(vault: Vault) {
        self.vault = vault
        setUp()
    }

    func isCurrentUser(_ invitee: any ShareInvitee) -> Bool {
        userDataProvider.getUserData()?.user.email == invitee.email
    }

    func shareWithMorePeople() {
        setShareInviteVault(with: .existing(vault))
        router.present(for: .sharingFlow(.none))
    }

    func fetchShareInformation(displayFetchingLoader: Bool = false) {
        fetchingTask?.cancel()
        fetchingTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            if displayFetchingLoader {
                fetching = true
            } else {
                loading = true
            }
            defer {
                if displayFetchingLoader {
                    fetching = false
                } else {
                    loading = false
                }
            }
            do {
                try await doFetchShareInformation()
            } catch {
                display(error: error)
                logger.error(message: "Failed to fetch the current share informations", error: error)
            }
        }
    }

    func canTransferOwnership(to invitee: any ShareInvitee) -> Bool {
        canUserTransferVaultOwnership(for: vault, to: invitee)
    }

    // swiftformat:disable all
    // swiftformat is confused when an async function takes an async autoclosure
    func handle(option: ShareInviteeOption) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                switch option {
                case let .remindExistingUserInvitation(inviteId):
                    try await execute(await sendInviteReminder(with: vault.shareId,
                                                               and: inviteId),
                                      shouldForceSync: false)

                case let .cancelExistingUserInvitation(inviteId):
                    try await execute(await revokeInvitation(with: vault.shareId,
                                                             and: inviteId))

                case let .cancelNewUserInvitation(inviteId):
                    try await execute(await revokeNewUserInvitation(with: vault.shareId,
                                                                    and: inviteId))

                case let .confirmAccess(access):
                    try await execute(await promoteNewUserInvite(vault: vault,
                                                                 inviteId: access.inviteId,
                                                                 email: access.email))

                case let .updateRole(shareId, role):
                    try await execute(await updateUserShareRole(userShareId: shareId,
                                                                shareId: vault.shareId,
                                                                shareRole: role),
                                      shouldForceSync: false)

                case let .revokeAccess(shareId):
                    try await execute(await revokeUserShareAccess(with: shareId,
                                                                  and: vault.shareId))

                case let .confirmTransferOwnership(newOwner):
                    self.newOwner = newOwner

                case let .transferOwnership(newOwner):
                    let element = UIElementDisplay.successMessage(
                        #localized("Vault has been transferred"),
                        config: nil)
                    try await execute(
                        await transferVaultOwnership(newOwnerID: newOwner.shareId,
                                                     shareId: vault.shareId),
                        elementDisplay: element)
                }
            } catch {
                logger.error(error)
                display(error: error)
            }
        }
    }
    // swiftformat:enable all

    func upgrade() {
        router.present(for: .upgradeFlow)
    }
}

private extension ManageSharedVaultViewModel {
    @MainActor
    func execute(_ action: @Sendable @autoclosure () async throws -> Void,
                 shouldForceSync: Bool = true,
                 elementDisplay: UIElementDisplay? = nil) async throws {
        defer { loading = false }
        loading = true

        try await action()
        try await doFetchShareInformation()

        if let elementDisplay {
            router.display(element: elementDisplay)
        }

        if shouldForceSync {
            syncEventLoop.forceSync()
        }
    }

    @MainActor
    func doFetchShareInformation() async throws {
        itemsNumber = getVaultItemCount(for: vault)
        if Task.isCancelled {
            return
        }
        let shareId = vault.shareId
        if vault.isAdmin {
            invitations = try await getPendingInvitationsForShare(with: shareId)
        }
        members = try await getUsersLinkedToShare(with: shareId)
    }
}

private extension ManageSharedVaultViewModel {
    func setUp() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            if let status = try? await accessRepository.getPlan().isFreeUser {
                isFreeUser = status
            }
        }
    }

    func display(error: Error) {
        router.display(element: .displayErrorBanner(error))
    }
}
