//
// CustomField.swift
// Proton Pass - Created on 24/11/2023.
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

import Foundation

public enum CustomFieldType: CaseIterable, Equatable, Sendable {
    case text, totp, hidden
}

public struct CustomField: Equatable, Hashable, Sendable, Identifiable {
    public let title: String
    public let type: CustomFieldType
    public var content: String

    public var id: Int { hashValue }

    public init(title: String, type: CustomFieldType, content: String) {
        self.title = title
        self.type = type
        self.content = content
    }

    init(from extraField: ProtonPassItemV1_ExtraField) {
        title = extraField.fieldName
        switch extraField.content {
        case let .text(extraText):
            type = .text
            content = extraText.content

        case let .totp(extraTotp):
            type = .totp
            content = extraTotp.totpUri

        case let .hidden(extraHidden):
            type = .hidden
            content = extraHidden.content

        default:
            type = .text
            content = ""
        }
    }
}
