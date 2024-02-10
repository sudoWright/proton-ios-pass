//
// LocalShareDatasource.swift
// Proton Pass - Created on 13/08/2022.
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

import CoreData

public protocol LocalShareDatasourceProtocol: Sendable {
    func getShare(userId: String, shareId: String) async throws -> SymmetricallyEncryptedShare?
    func getAllShares(userId: String) async throws -> [SymmetricallyEncryptedShare]
    func upsertShares(_ shares: [SymmetricallyEncryptedShare], userId: String) async throws
    func removeShare(shareId: String, userId: String) async throws
    func removeAllShares(userId: String) async throws
}

public final class LocalShareDatasource: LocalDatasource, LocalShareDatasourceProtocol {}

public extension LocalShareDatasource {
    func getShare(userId: String, shareId: String) async throws -> SymmetricallyEncryptedShare? {
        let taskContext = newTaskContext(type: .fetch)

        let fetchRequest = ShareEntity.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            .init(format: "userID = %@", userId),
            .init(format: "shareID = %@", shareId)
        ])
        let shareEntities = try await execute(fetchRequest: fetchRequest,
                                              context: taskContext)
        return shareEntities.map { $0.toSymmetricallyEncryptedShare() }.first
    }

    func getAllShares(userId: String) async throws -> [SymmetricallyEncryptedShare] {
        let taskContext = newTaskContext(type: .fetch)

        let fetchRequest = ShareEntity.fetchRequest()
        fetchRequest.predicate = .init(format: "userID = %@", userId)
        fetchRequest.sortDescriptors = [.init(key: "createTime", ascending: false)]
        let shareEntities = try await execute(fetchRequest: fetchRequest,
                                              context: taskContext)
        return shareEntities.map { $0.toSymmetricallyEncryptedShare() }
    }

    func upsertShares(_ shares: [SymmetricallyEncryptedShare], userId: String) async throws {
        let taskContext = newTaskContext(type: .insert)

        let batchInsertRequest =
            newBatchInsertRequest(entity: ShareEntity.entity(context: taskContext),
                                  sourceItems: shares) { managedObject, share in
                (managedObject as? ShareEntity)?.hydrate(from: share, userId: userId)
            }

        try await execute(batchInsertRequest: batchInsertRequest, context: taskContext)
    }

    func removeShare(shareId: String, userId: String) async throws {
        let taskContext = newTaskContext(type: .delete)
        let fetchRequest = NSFetchRequest<any NSFetchRequestResult>(entityName: "ShareEntity")
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            .init(format: "userID = %@", userId),
            .init(format: "shareID = %@", shareId)
        ])
        try await execute(batchDeleteRequest: .init(fetchRequest: fetchRequest),
                          context: taskContext)
    }

    func removeAllShares(userId: String) async throws {
        let taskContext = newTaskContext(type: .delete)
        let fetchRequest = NSFetchRequest<any NSFetchRequestResult>(entityName: "ShareEntity")
        fetchRequest.predicate = .init(format: "userID = %@", userId)
        try await execute(batchDeleteRequest: .init(fetchRequest: fetchRequest),
                          context: taskContext)
    }
}
