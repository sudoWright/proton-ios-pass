//
// AccessEntity.swift
// Proton Pass - Created on 04/05/2023.
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

import CoreData
import Entities

@objc(AccessEntity)
public class AccessEntity: NSManagedObject {}

extension AccessEntity: Identifiable {}

extension AccessEntity {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<AccessEntity> {
        NSFetchRequest<AccessEntity>(entityName: "AccessEntity")
    }

    @NSManaged var displayName: String
    @NSManaged var hideUpgrade: Bool
    @NSManaged var internalName: String
    @NSManaged var type: String
    @NSManaged var userID: String

    // All limits are -1 by default (unlimited)
    @NSManaged var aliasLimit: Int64
    @NSManaged var totpLimit: Int64
    @NSManaged var trialEnd: Int64
    @NSManaged var vaultLimit: Int64

    @NSManaged var pendingInvites: Int64
    @NSManaged var waitingNewUserInvites: Int64
}

extension AccessEntity {
    func toAccess() -> Access {
        let plan = Plan(type: type,
                        internalName: internalName,
                        displayName: displayName,
                        hideUpgrade: hideUpgrade,
                        trialEnd: trialEnd == -1 ? nil : Int(trialEnd),
                        vaultLimit: vaultLimit == -1 ? nil : Int(vaultLimit),
                        aliasLimit: aliasLimit == -1 ? nil : Int(aliasLimit),
                        totpLimit: totpLimit == -1 ? nil : Int(totpLimit))
        return .init(plan: plan,
                     pendingInvites: Int(pendingInvites),
                     waitingNewUserInvites: Int(waitingNewUserInvites))
    }

    func hydrate(from access: Access, userId: String) {
        let plan = access.plan
        displayName = plan.displayName
        internalName = plan.internalName
        hideUpgrade = plan.hideUpgrade
        type = plan.type
        userID = userId
        aliasLimit = Int64(plan.aliasLimit ?? -1)
        totpLimit = Int64(plan.totpLimit ?? -1)
        trialEnd = Int64(plan.trialEnd ?? -1)
        vaultLimit = Int64(plan.vaultLimit ?? -1)

        pendingInvites = Int64(access.pendingInvites)
        waitingNewUserInvites = Int64(access.waitingNewUserInvites)
    }
}
