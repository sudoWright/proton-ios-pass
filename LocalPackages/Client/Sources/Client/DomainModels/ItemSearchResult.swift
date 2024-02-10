//
// ItemSearchResult.swift
// Proton Pass - Created on 21/09/2022.
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

import Core
import Entities
import UIKit

public protocol HighlightableText: Sendable {
    var fullText: String { get }
    var highlightText: String? { get }
    var isLeadingText: Bool { get }
    var isTrailingText: Bool { get }
}

public enum SearchResultEither: HighlightableText {
    case notMatched(String)
    case matched(SearchResult)

    public var fullText: String {
        switch self {
        case let .notMatched(text):
            text
        case let .matched(searchResult):
            searchResult.matchedPhrase
        }
    }

    public var highlightText: String? {
        switch self {
        case .notMatched:
            nil
        case let .matched(searchResult):
            searchResult.matchedWord
        }
    }

    public var isLeadingText: Bool {
        switch self {
        case .notMatched:
            true
        case let .matched(searchResult):
            searchResult.isLeadingPhrase
        }
    }

    public var isTrailingText: Bool {
        switch self {
        case .notMatched:
            true
        case let .matched(searchResult):
            searchResult.isTrailingPhrase
        }
    }
}

public struct ItemSearchResult: ItemTypeIdentifiable, Identifiable, Pinnable {
    public var id: String {
        "\(itemId + shareId)"
    }

    public let shareId: String
    public let itemId: String
    public let type: ItemContentType
    public let aliasEmail: String?
    public let highlightableTitle: any HighlightableText
    public let highlightableDetail: [any HighlightableText]
    public let url: String?
    public let vault: Vault?
    public let lastUseTime: Int64
    public let modifyTime: Int64
    public let pinned: Bool

    public init(shareId: String,
                itemId: String,
                type: ItemContentType,
                aliasEmail: String?,
                title: SearchResultEither,
                detail: [SearchResultEither],
                url: String?,
                vault: Vault?,
                lastUseTime: Int64,
                modifyTime: Int64,
                pinned: Bool) {
        self.shareId = shareId
        self.itemId = itemId
        self.type = type
        self.aliasEmail = aliasEmail
        highlightableTitle = title
        highlightableDetail = detail
        self.url = url
        self.vault = vault
        self.lastUseTime = lastUseTime
        self.modifyTime = modifyTime
        self.pinned = pinned
    }
}

extension ItemSearchResult: ItemThumbnailable {
    public var title: String { highlightableTitle.fullText }
}

extension ItemSearchResult: DateSortable {
    public var dateForSorting: Date {
        Date(timeIntervalSince1970: TimeInterval(max(lastUseTime, modifyTime)))
    }
}

extension ItemSearchResult: AlphabeticalSortable {
    public var alphabeticalSortableString: String { highlightableTitle.fullText }
}

extension ItemSearchResult: Hashable {
    public static func == (lhs: ItemSearchResult, rhs: ItemSearchResult) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(itemId)
        hasher.combine(shareId)
        let texts = [highlightableTitle.highlightText] + highlightableDetail.map(\.highlightText)
        hasher.combine(texts)
    }
}
