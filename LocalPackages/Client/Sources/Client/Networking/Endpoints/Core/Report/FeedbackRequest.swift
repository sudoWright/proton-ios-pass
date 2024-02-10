//
// FeedbackRequest.swift
// Proton Pass - Created on 03/07/2023.
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

public struct FeedbackRequest: Sendable {
    public let feedbackType: String
    public let feedback: String
    public let score: Int

    public init(with feedbackType: String, and feedback: String, score: Int = 0) {
        self.feedbackType = feedbackType
        self.feedback = feedback
        self.score = score
    }
}

extension FeedbackRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case feedbackType = "FeedbackType"
        case feedback = "Feedback"
        case score = "Score"
    }
}
