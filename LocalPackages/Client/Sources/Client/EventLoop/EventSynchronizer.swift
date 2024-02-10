//
// EventSynchronizer.swift
// Proton Pass - Created on 16/11/2023.
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

import Core
import Entities
import Foundation
import ProtonCoreNetworking

/*
 Steps of a sync:
 1. Fetch all shares from remote and local
 2. Compare recently fetched shares with local ones.
    if discrepancies found update or remove local shares as remote share are the source of truth.

    For each new share do the full sync procedure.
    For each existing share, do the step 3 of the full sync procedure.

 Full sync procedure:
 1. Get the last eventID from remote
 2. Get the share data (keys, items...) and store in the local db
 3. Get events from api using last eventID
    a. Upsert `UpdatedItems`
    b. Delete `DeletedItemIDs`
    d. If `NewRotationID` is not null. Refresh the keys of the share.
    e. Upsert `LatestEventID` of the share.
    f. If `EventsPending` is `true`. Repeat this step with the given `LatestEventID`.
 */

public protocol EventSynchronizerProtocol: Actor {
    func sync() async throws -> Bool
}

public actor EventSynchronizer: EventSynchronizerProtocol {
    private let shareRepository: any ShareRepositoryProtocol
    private let itemRepository: any ItemRepositoryProtocol
    private let shareKeyRepository: any ShareKeyRepositoryProtocol
    private let shareEventIDRepository: any ShareEventIDRepositoryProtocol
    private let remoteSyncEventsDatasource: any RemoteSyncEventsDatasourceProtocol
    private let userDataProvider: any UserDataProvider
    private let logger: Logger

    public init(shareRepository: any ShareRepositoryProtocol,
                itemRepository: any ItemRepositoryProtocol,
                shareKeyRepository: any ShareKeyRepositoryProtocol,
                shareEventIDRepository: any ShareEventIDRepositoryProtocol,
                remoteSyncEventsDatasource: any RemoteSyncEventsDatasourceProtocol,
                userDataProvider: any UserDataProvider,
                logManager: any LogManagerProtocol) {
        self.shareRepository = shareRepository
        self.itemRepository = itemRepository
        self.shareKeyRepository = shareKeyRepository
        self.shareEventIDRepository = shareEventIDRepository
        self.remoteSyncEventsDatasource = remoteSyncEventsDatasource
        self.userDataProvider = userDataProvider
        logger = .init(manager: logManager)
    }

    /// Return `true` if new events found
    @discardableResult
    public func sync() async throws -> Bool {
        // Need to sync 3 operations in 2 steps:
        // 1. Create & update sync
        // 2. Delete sync
        async let fetchLocalShares = shareRepository.getShares()
        async let fetchRemoteShares = shareRepository.getRemoteShares()

        if Task.isCancelled {
            return false
        }
        var (localShares, remoteShares) = try await (fetchLocalShares, fetchRemoteShares)

        let updatedShares = try await removeSuperfluousLocalShares(localShares: localShares,
                                                                   remoteShares: remoteShares)
        if updatedShares {
            if Task.isCancelled {
                return true
            }

            /// Updating the local shares with the latest information as `updatedShares` notifies of local
            /// share changes.
            localShares = try await shareRepository.getShares()
        }
        if Task.isCancelled {
            return false
        }

        let hasNewEvents = try await syncCreateAndUpdateEvents(localShares: localShares,
                                                               remoteShares: remoteShares)

        return hasNewEvents || updatedShares
    }
}

// MARK: Private APIs

// MARK: - Sharing Events

private extension EventSynchronizer {
    func removeSuperfluousLocalShares(localShares: [SymmetricallyEncryptedShare],
                                      remoteShares: [Share]) async throws -> Bool {
        // This is used to respond to sharing modifications that are not tied to events in the BE
        // making changes not visible to the user.
        if !remoteShares.isLooselyEqual(to: localShares.map(\.share)) {
            // Update local shares based on remote shares that are the source of truth
            let remoteShareIDs = Set(remoteShares.map(\.shareID))

            // Filter local shares not present in remote shares
            let deletedLocalShares = localShares.filter { !remoteShareIDs.contains($0.share.shareID) }

            // Delete local shares if there are any to delete
            if !deletedLocalShares.isEmpty {
                try await delete(shares: deletedLocalShares)
            }

            return true
        }
        return false
    }

    func delete(shares: [SymmetricallyEncryptedShare]) async throws {
        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for share in shares {
                let shareId = share.share.shareID
                taskGroup.addTask { [weak self] in
                    guard let self else { return }
                    try await shareRepository.deleteShareLocally(shareId: shareId)
                }
                taskGroup.addTask { [weak self] in
                    guard let self else { return }
                    try await itemRepository.deleteAllItemsLocally(shareId: shareId)
                }
            }
        }
    }
}

// MARK: - Sync Utils

private extension EventSynchronizer {
    /// Return `true` if new events found
    func syncCreateAndUpdateEvents(localShares: [SymmetricallyEncryptedShare],
                                   remoteShares: [Share]) async throws -> Bool {
        let localShareIDs = Set(localShares.map(\.share.shareID))

        return try await withThrowingTaskGroup(of: Bool.self, returning: Bool.self) { taskGroup in
            for remoteShare in remoteShares {
                let shareId = remoteShare.shareID
                taskGroup.addTask { [weak self] in
                    guard let self else { return false }

                    let isExistingShare = localShareIDs.contains(shareId)
                    let loggerMessage = isExistingShare ? "Existing share \(shareId)" :
                        "New share \(shareId)"
                    logger.trace(loggerMessage)

                    if isExistingShare {
                        return try await handleExistingShare(remoteShare: remoteShare)
                    } else {
                        try await handleNewShare(remoteShare: remoteShare)
                        return true
                    }
                }
            }

            var foundNewEvent = false
            for try await hasNewEvents in taskGroup where hasNewEvents == true {
                foundNewEvent = true
            }

            return foundNewEvent
        }
    }

    /// Handle existing share processing
    func handleExistingShare(remoteShare: Share) async throws -> Bool {
        // We are deleting the share from local storage because of a bug in Core data
        // not taking into account any boolean value changes.
        try await shareRepository.deleteShareLocally(shareId: remoteShare.shareID)
        try await shareRepository.upsertShares([remoteShare])
        try Task.checkCancellation()
        return try await sync(share: remoteShare)
    }

    /// Handle new share processing
    func handleNewShare(remoteShare: Share) async throws {
        let shareId = remoteShare.shareID

        do {
            try Task.checkCancellation()
            async let upsertShares: Void = shareRepository.upsertShares([remoteShare])
            async let refreshItems: Void = itemRepository.refreshItems(shareId: shareId)
            try Task.checkCancellation()
            _ = try await (upsertShares, refreshItems)
        } catch {
            if let passError = error as? PassError,
               case let .crypto(reason) = passError,
               case .inactiveUserKey = reason {
                // Ignore the case where user key is inactive
                logger.warning(reason.debugDescription)
            } else {
                throw error
            }
        }
    }

    /// Sync a single share. Can be a recursion if share has many events
    func sync(share: Share) async throws -> Bool {
        let userId = try userDataProvider.getUserId()
        let shareId = share.shareID
        logger.trace("Syncing share \(shareId)")
        return try await performSyncOperations(userId: userId, shareId: shareId)
    }

    /// Perform synchronization operations
    func performSyncOperations(userId: String, shareId: ShareID) async throws -> Bool {
        try Task.checkCancellation()

        let lastEventId = try await shareEventIDRepository.getLastEventId(forceRefresh: false,
                                                                          userId: userId,
                                                                          shareId: shareId)
        try Task.checkCancellation()
        let events = try await remoteSyncEventsDatasource.getEvents(shareId: shareId,
                                                                    lastEventId: lastEventId)
        try Task.checkCancellation()
        try await shareEventIDRepository.upsertLastEventId(userId: userId,
                                                           shareId: shareId,
                                                           lastEventId: events.latestEventID)
        try Task.checkCancellation()

        let hasNewEvents = try await processEvents(events: events, shareId: shareId)

        if events.eventsPending {
            logger.trace("Still have more events for share \(shareId)")
            return try await performSyncOperations(userId: userId, shareId: shareId)
        }
        return hasNewEvents
    }

    /// Process the events from synchronization
    func processEvents(events: SyncEvents, shareId: ShareID) async throws -> Bool {
        if events.fullRefresh {
            logger.info("Force full sync for share \(shareId)")
            try await itemRepository.refreshItems(shareId: shareId)
            return true
        } else {
            return try await processEventDetails(events: events, shareId: shareId)
        }
    }

    /// Process the detailed parts of the events
    func processEventDetails(events: SyncEvents, shareId: ShareID) async throws -> Bool {
        var hasNewEvents = false
        try Task.checkCancellation()
        if let updatedShare = events.updatedShare {
            hasNewEvents = try await handleUpdateEvent(description: "updated",
                                                       count: 1,
                                                       shareId: shareId) { [weak self] in
                guard let self else {
                    return
                }
                try await shareRepository.upsertShares([updatedShare])
            }
        }

        try Task.checkCancellation()
        if !events.updatedItems.isEmpty {
            hasNewEvents = try await handleUpdateEvent(description: "updated items",
                                                       count: events.updatedItems.count,
                                                       shareId: shareId) { [weak self] in
                guard let self else {
                    return
                }
                try await itemRepository.upsertItems(events.updatedItems, shareId: shareId)
            }
        }

        try Task.checkCancellation()
        if !events.deletedItemIDs.isEmpty {
            hasNewEvents = try await handleUpdateEvent(description: "deleted items",
                                                       count: events.deletedItemIDs.count,
                                                       shareId: shareId) { [weak self] in
                guard let self else {
                    return
                }
                try await itemRepository.deleteItemsLocally(itemIds: events.deletedItemIDs,
                                                            shareId: shareId)
            }
        }

        try Task.checkCancellation()
        if !events.lastUseItems.isEmpty {
            hasNewEvents = try await handleUpdateEvent(description: "lastUseItem",
                                                       count: events.lastUseItems.count,
                                                       shareId: shareId) { [weak self] in
                guard let self else {
                    return
                }
                try await itemRepository.update(lastUseItems: events.lastUseItems, shareId: shareId)
            }
        }

        try Task.checkCancellation()
        if events.newKeyRotation != nil {
            hasNewEvents = try await handleUpdateEvent(description: "new rotation ID",
                                                       count: 1,
                                                       shareId: shareId) { [weak self] in
                guard let self else {
                    return
                }
                _ = try await shareKeyRepository.refreshKeys(shareId: shareId)
            }
        }

        return hasNewEvents
    }

    /// Handle an update event, logging and setting the flag
    func handleUpdateEvent(description: String,
                           count: Int,
                           shareId: ShareID,
                           operation: @escaping () async throws -> Void) async throws -> Bool {
        logger.trace("Found \(count) \(description) for share \(shareId)")
        try await operation()
        return true
    }
}
