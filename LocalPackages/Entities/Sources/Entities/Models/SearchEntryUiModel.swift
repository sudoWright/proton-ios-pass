//
// SearchEntryUiModel.swift
// Proton Pass - Created on 17/03/2023.
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

public struct SearchEntryUiModel: ItemIdentifiable {
    public let itemId: String
    public let shareId: String
    public let type: ItemContentType
    public let title: String
    public let url: String?
    public let description: String?

    public init(itemId: String,
                shareId: String,
                type: ItemContentType,
                title: String,
                url: String?,
                description: String?) {
        self.itemId = itemId
        self.shareId = shareId
        self.type = type
        self.title = title
        self.url = url
        self.description = description
    }
}

extension SearchEntryUiModel: Identifiable {
    public var id: String { itemId + shareId }
}

extension SearchEntryUiModel: ItemThumbnailable {}

extension SearchEntryUiModel: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.shareId == rhs.shareId && lhs.itemId == rhs.itemId
    }
}
