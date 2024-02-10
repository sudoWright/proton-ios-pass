//
// UseCases+DependencyInjections.swift
// Proton Pass - Created on 29/06/2023.
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
import Factory
import ProtonCoreServices
import UseCases

final class UseCasesContainer: SharedContainer, AutoRegistering, Sendable {
    static let shared = UseCasesContainer()
    let manager = ContainerManager()

    func autoRegister() {
        manager.defaultScope = .shared
    }
}

// MARK: - Computed properties

private extension UseCasesContainer {
    var logManager: LogManagerProtocol {
        SharedToolingContainer.shared.logManager()
    }

    var shareInviteService: ShareInviteServiceProtocol {
        ServiceContainer.shared.shareInviteService()
    }

    var userDataProvider: UserDataProvider {
        SharedDataContainer.shared.userDataProvider()
    }

    var itemRepository: any ItemRepositoryProtocol {
        SharedRepositoryContainer.shared.itemRepository()
    }
}

// MARK: User report

extension UseCasesContainer {
    var sendUserBugReport: Factory<SendUserBugReportUseCase> {
        self { SendUserBugReport(reportRepository: RepositoryContainer.shared.reportRepository(),
                                 extractLogsToFile: self.extractLogsToFile(),
                                 getLogEntries: self.getLogEntries()) }
    }
}

// MARK: Logs

extension UseCasesContainer {
    var extractLogsToFile: Factory<ExtractLogsToFileUseCase> {
        self { ExtractLogsToFile(logFormatter: SharedToolingContainer.shared.logFormatter()) }
    }

    var getLogEntries: Factory<GetLogEntriesUseCase> {
        self { GetLogEntries(mainAppLogManager: SharedToolingContainer.shared.specificLogManager(.hostApp),
                             autofillLogManager: SharedToolingContainer.shared
                                 .specificLogManager(.autoFillExtension),
                             keyboardLogManager: SharedToolingContainer.shared
                                 .specificLogManager(.keyboardExtension),
                             shareLogManager: SharedToolingContainer.shared
                                 .specificLogManager(.shareExtension)) }
    }
}

// MARK: - Sharing

extension UseCasesContainer {
    var createAndMoveItemToNewVault: Factory<CreateAndMoveItemToNewVaultUseCase> {
        self { CreateAndMoveItemToNewVault(createVault: self.createVault(),
                                           moveItemsBetweenVaults: self.moveItemsBetweenVaults(),
                                           vaultsManager: SharedServiceContainer.shared.vaultsManager()) }
    }

    var getCurrentShareInviteInformations: Factory<GetCurrentShareInviteInformationsUseCase> {
        self { GetCurrentShareInviteInformations(shareInviteService: self.shareInviteService)
        }
    }

    var setShareInviteVault: Factory<SetShareInviteVaultUseCase> {
        self { SetShareInviteVault(shareInviteService: self.shareInviteService,
                                   getVaultItemCount: self.getVaultItemCount()) }
    }

    var setShareInvitesUserEmailsAndKeys: Factory<SetShareInvitesUserEmailsAndKeysUseCase> {
        self { SetShareInvitesUserEmailsAndKeys(shareInviteService: self.shareInviteService,
                                                getEmailPublicKeyUseCase: self.getEmailPublicKey()) }
    }

    var setShareInviteRole: Factory<SetShareInviteRoleUseCase> {
        self { SetShareInviteRole(shareInviteService: self.shareInviteService) }
    }

    var sendVaultShareInvite: Factory<SendVaultShareInviteUseCase> {
        self { SendVaultShareInvite(createAndMoveItemToNewVault: self.createAndMoveItemToNewVault(),
                                    makeUnsignedSignatureForVaultSharing: self
                                        .makeUnsignedSignatureForVaultSharing(),
                                    shareInviteService: self.shareInviteService,
                                    passKeyManager: SharedRepositoryContainer.shared.passKeyManager(),
                                    shareInviteRepository: SharedRepositoryContainer.shared
                                        .shareInviteRepository(),
                                    userDataProvider: self.userDataProvider,
                                    syncEventLoop: SharedServiceContainer.shared.syncEventLoop()) }
    }

    var promoteNewUserInvite: Factory<PromoteNewUserInviteUseCase> {
        self { PromoteNewUserInvite(publicKeyRepository: SharedRepositoryContainer.shared.publicKeyRepository(),
                                    passKeyManager: SharedRepositoryContainer.shared.passKeyManager(),
                                    shareInviteRepository: SharedRepositoryContainer.shared
                                        .shareInviteRepository(),
                                    userDataProvider: self.userDataProvider) }
    }

    var getEmailPublicKey: Factory<GetEmailPublicKeyUseCase> {
        self { GetEmailPublicKey(publicKeyRepository: SharedRepositoryContainer.shared.publicKeyRepository()) }
    }

    var leaveShare: Factory<LeaveShareUseCase> {
        self { LeaveShare(vaultManager: SharedServiceContainer.shared.vaultsManager()) }
    }

    var getUsersLinkedToShare: Factory<GetUsersLinkedToShareUseCase> {
        self { GetUsersLinkedToShare(repository: SharedRepositoryContainer.shared.shareRepository()) }
    }

    var getPendingInvitationsForShare: Factory<GetPendingInvitationsForShareUseCase> {
        self { GetPendingInvitationsForShare(repository: SharedRepositoryContainer.shared.shareInviteRepository())
        }
    }

    var updateUserShareRole: Factory<UpdateUserShareRoleUseCase> {
        self { UpdateUserShareRole(repository: SharedRepositoryContainer.shared.shareRepository()) }
    }

    var revokeUserShareAccess: Factory<RevokeUserShareAccessUseCase> {
        self { RevokeUserShareAccess(repository: SharedRepositoryContainer.shared.shareRepository()) }
    }

    var getUserShareStatus: Factory<GetUserShareStatusUseCase> {
        self {
            GetUserShareStatus(accessRepository: SharedRepositoryContainer.shared.accessRepository())
        }
    }

    var canUserPerformActionOnVault: Factory<CanUserPerformActionOnVaultUseCase> {
        self {
            CanUserPerformActionOnVault(accessRepository: SharedRepositoryContainer.shared.accessRepository(),
                                        vaultsManager: SharedServiceContainer.shared.vaultsManager())
        }
    }
}

// MARK: - Invites

extension UseCasesContainer {
    var getPendingUserInvitations: Factory<GetPendingUserInvitationsUseCase> {
        self { GetPendingUserInvitations(repository: RepositoryContainer.shared.inviteRepository()) }
    }

    var refreshInvitations: Factory<RefreshInvitationsUseCase> {
        self { RefreshInvitations(inviteRepository: RepositoryContainer.shared.inviteRepository(),
                                  accessRepository: SharedRepositoryContainer.shared.accessRepository()) }
    }

    var rejectInvitation: Factory<RejectInvitationUseCase> {
        self { RejectInvitation(repository: RepositoryContainer.shared.inviteRepository()) }
    }

    var acceptInvitation: Factory<AcceptInvitationUseCase> {
        self { AcceptInvitation(repository: RepositoryContainer.shared.inviteRepository(),
                                userDataProvider: self.userDataProvider,
                                getEmailPublicKey: self.getEmailPublicKey(),
                                updateUserAddresses: self.updateUserAddresses(),
                                logManager: self.logManager) }
    }

    var decodeShareVaultInformation: Factory<DecodeShareVaultInformationUseCase> {
        self { DecodeShareVaultInformation(userDataProvider: self.userDataProvider,
                                           getEmailPublicKey: self.getEmailPublicKey(),
                                           updateUserAddresses: self.updateUserAddresses(),
                                           logManager: self.logManager) }
    }

    var updateCachedInvitations: Factory<UpdateCachedInvitationsUseCase> {
        self { UpdateCachedInvitations(repository: RepositoryContainer.shared.inviteRepository()) }
    }

    var revokeInvitation: Factory<RevokeInvitationUseCase> {
        self { RevokeInvitation(shareInviteRepository: SharedRepositoryContainer.shared.shareInviteRepository()) }
    }

    var revokeNewUserInvitation: Factory<RevokeNewUserInvitationUseCase> {
        self {
            RevokeNewUserInvitation(shareInviteRepository: SharedRepositoryContainer.shared
                .shareInviteRepository())
        }
    }

    var sendInviteReminder: Factory<SendInviteReminderUseCase> {
        self { SendInviteReminder(shareInviteRepository: SharedRepositoryContainer.shared.shareInviteRepository())
        }
    }

    var canUserTransferVaultOwnership: Factory<CanUserTransferVaultOwnershipUseCase> {
        self { CanUserTransferVaultOwnership(vaultsManager: SharedServiceContainer.shared.vaultsManager()) }
    }

    var makeUnsignedSignatureForVaultSharing: Factory<MakeUnsignedSignatureForVaultSharingUseCase> {
        self { MakeUnsignedSignatureForVaultSharing() }
    }
}

// MARK: - Flags

extension UseCasesContainer {
    var refreshFeatureFlags: Factory<RefreshFeatureFlagsUseCase> {
        self { RefreshFeatureFlags(repository: SharedRepositoryContainer.shared.featureFlagsRepository(),
                                   userDataProvider: self.userDataProvider,
                                   logManager: self.logManager) }
    }
}

// MARK: - Vaults

extension UseCasesContainer {
    var getVaultItemCount: Factory<GetVaultItemCountUseCase> {
        self { GetVaultItemCount(vaultsManager: SharedServiceContainer.shared.vaultsManager()) }
    }

    var transferVaultOwnership: Factory<TransferVaultOwnershipUseCase> {
        self { TransferVaultOwnership(repository: SharedRepositoryContainer.shared.shareRepository()) }
    }

    var moveItemsBetweenVaults: Factory<MoveItemsBetweenVaultsUseCase> {
        self { MoveItemsBetweenVaults(repository: self.itemRepository) }
    }

    var trashSelectedItems: Factory<TrashSelectedItemsUseCase> {
        self { TrashSelectedItems(repository: self.itemRepository) }
    }

    var restoreSelectedItems: Factory<RestoreSelectedItemsUseCase> {
        self { RestoreSelectedItems(repository: self.itemRepository) }
    }

    var permanentlyDeleteSelectedItems: Factory<PermanentlyDeleteSelectedItemsUseCase> {
        self { PermanentlyDeleteSelectedItems(repository: self.itemRepository) }
    }

    var getVaultContentForVault: Factory<GetVaultContentForVaultUseCase> {
        self { GetVaultContentForVault(vaultsManager: SharedServiceContainer.shared.vaultsManager()) }
    }

    var createVault: Factory<CreateVaultUseCase> {
        self { CreateVault(vaultsManager: SharedServiceContainer.shared.vaultsManager(),
                           repository: SharedRepositoryContainer.shared.shareRepository()) }
    }

    var reachedVaultLimit: Factory<ReachedVaultLimitUseCase> {
        self { ReachedVaultLimit(accessRepository: SharedRepositoryContainer.shared.accessRepository(),
                                 vaultsManager: SharedServiceContainer.shared.vaultsManager()) }
    }
}

// MARK: - items

extension UseCasesContainer {
    var getAllPinnedItems: Factory<GetAllPinnedItemsUseCase> {
        self { GetAllPinnedItems(itemRepository: self.itemRepository) }
    }

    var getSearchableItems: Factory<GetSearchableItemsUseCase> {
        self { GetSearchableItems(itemRepository: self.itemRepository,
                                  shareRepository: SharedRepositoryContainer.shared.shareRepository(),
                                  getAllPinnedItems: self.getAllPinnedItems(),
                                  symmetricKeyProvider: SharedDataContainer.shared.symmetricKeyProvider()) }
    }

    var getItemHistory: Factory<GetItemHistoryUseCase> {
        self { GetItemHistory(itemRepository: self.itemRepository) }
    }
}

// MARK: - User

extension UseCasesContainer {
    var updateUserAddresses: Factory<UpdateUserAddressesUseCase> {
        self { UpdateUserAddresses(userDataProvider: self.userDataProvider,
                                   authenticator: ServiceContainer.shared.authenticator()) }
    }
}

// MARK: - Misc

extension UseCasesContainer {
    var getRustLibraryVersion: Factory<GetRustLibraryVersionUseCase> {
        self { GetRustLibraryVersion() }
    }

    @MainActor
    var openAutoFillSettings: Factory<OpenAutoFillSettingsUseCase> {
        self { OpenAutoFillSettings(router: SharedRouterContainer.shared.mainUIKitSwiftUIRouter()) }
    }

    var makeImportExportUrl: Factory<MakeImportExportUrlUseCase> {
        self { MakeImportExportUrl(doh: SharedToolingContainer.shared.doh()) }
    }

    var makeAccountSettingsUrl: Factory<MakeAccountSettingsUrlUseCase> {
        self { MakeAccountSettingsUrl(doh: SharedToolingContainer.shared.doh()) }
    }
}
