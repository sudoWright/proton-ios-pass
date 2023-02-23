//
// ItemEntity.swift
// Proton Pass - Created on 20/09/2022.
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

@objc(ItemEntity)
public class ItemEntity: NSManagedObject {}

extension ItemEntity: Identifiable {}

extension ItemEntity {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<ItemEntity> {
        NSFetchRequest<ItemEntity>(entityName: "ItemEntity")
    }

    @NSManaged var aliasEmail: String?
    @NSManaged var content: String?
    @NSManaged var contentFormatVersion: Int16
    @NSManaged var createTime: Int64
    @NSManaged var isLogInItem: Bool // Custom field
    @NSManaged var itemID: String?
    @NSManaged var itemKey: String?
    @NSManaged var keyRotation: Int64
    @NSManaged var lastUseTime: Int64
    @NSManaged var modifyTime: Int64
    @NSManaged var revision: Int64
    @NSManaged var revisionTime: Int64
    @NSManaged var shareID: String? // Custom field
    @NSManaged var state: Int16
    @NSManaged var symmetricallyEncryptedContent: String? // Custom field
}

extension ItemEntity {
    func toEncryptedItem() throws -> SymmetricallyEncryptedItem {
        guard let shareID else {
            throw PPClientError.coreData(.corrupted(object: self, property: "shareID"))
        }

        guard let itemID else {
            throw PPClientError.coreData(.corrupted(object: self, property: "itemID"))
        }

        guard let symmetricallyEncryptedContent else {
            throw PPClientError.coreData(.corrupted(object: self,
                                                    property: "symmetricallyEncryptedContent"))
        }

        guard let content else {
            throw PPClientError.coreData(.corrupted(object: self, property: "content"))
        }

        let itemRevision = ItemRevision(itemID: itemID,
                                        revision: revision,
                                        contentFormatVersion: contentFormatVersion,
                                        keyRotation: keyRotation,
                                        content: content,
                                        itemKey: itemKey,
                                        state: state,
                                        aliasEmail: aliasEmail,
                                        createTime: createTime,
                                        modifyTime: modifyTime,
                                        lastUseTime: lastUseTime,
                                        revisionTime: revisionTime)

        return .init(shareId: shareID,
                     item: itemRevision,
                     encryptedContent: symmetricallyEncryptedContent,
                     isLogInItem: isLogInItem)
    }

    func hydrate(from symmetricallyEncryptedItem: SymmetricallyEncryptedItem) {
        let item = symmetricallyEncryptedItem.item
        self.aliasEmail = item.aliasEmail
        self.content = item.content
        self.contentFormatVersion = item.contentFormatVersion
        self.createTime = item.createTime
        self.isLogInItem = symmetricallyEncryptedItem.isLogInItem
        self.itemID = item.itemID
        self.itemKey = item.itemKey
        self.keyRotation = item.keyRotation
        self.lastUseTime = item.lastUseTime
        self.modifyTime = item.modifyTime
        self.revision = item.revision
        self.revisionTime = item.revisionTime
        self.shareID = symmetricallyEncryptedItem.shareId
        self.state = item.state
        self.symmetricallyEncryptedContent = symmetricallyEncryptedItem.encryptedContent
    }
}
