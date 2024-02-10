//
// AppLockTime.swift
// Proton Pass - Created on 27/04/2023.
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
import Macro

public enum AppLockTime: Int, Codable, CustomStringConvertible, CaseIterable {
    case immediately = 0
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 3
    case tenMinutes = 4
    case oneHour = 5
    case fourHours = 6
    case never = 7

    public var description: String {
        switch self {
        case .immediately:
            #localized("Immediately")
        case .oneMinute:
            #localized("After %lld minute(s)", 1)
        case .twoMinutes:
            #localized("After %lld minute(s)", 2)
        case .fiveMinutes:
            #localized("After %lld minute(s)", 5)
        case .tenMinutes:
            #localized("After %lld minute(s)", 10)
        case .oneHour:
            #localized("After %lld hour(s)", 1)
        case .fourHours:
            #localized("After %lld hour(s)", 4)
        case .never:
            #localized("Never")
        }
    }

    public var intervalInMinutes: Int? {
        switch self {
        case .immediately:
            0
        case .oneMinute:
            1
        case .twoMinutes:
            2
        case .fiveMinutes:
            5
        case .tenMinutes:
            10
        case .oneHour:
            60
        case .fourHours:
            240
        case .never:
            nil
        }
    }
}
