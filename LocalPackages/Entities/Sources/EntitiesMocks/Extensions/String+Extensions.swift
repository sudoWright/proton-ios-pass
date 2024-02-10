//
// String+Extensions.swift
// Proton Pass - Created on 04/12/2023.
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

public enum AllowedCharacter: String {
    case lowercase = "abcdefghjkmnpqrstuvwxyz"
    case uppercase = "ABCDEFGHJKMNPQRSTUVWXYZ"
    case digit = "0123456789"
    case special = "!#$%&()*+.:;<=>?@[]^"
    case separator = "-.,_"
}

extension String {
    static func random(allowedCharacters: [AllowedCharacter] = [.lowercase, .uppercase, .digit],
                       length: Int = 10) -> String {
        let allCharacters = allowedCharacters.map(\.rawValue).reduce(into: "") { $0 += $1 }
        // swiftlint:disable:next todo
        // TODO: Make sure that returned string contains at least 1 character from each AllowedCharacter set
        return String((0..<length).compactMap { _ in allCharacters.randomElement() })
    }
}
