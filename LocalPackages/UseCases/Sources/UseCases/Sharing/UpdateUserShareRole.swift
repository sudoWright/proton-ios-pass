//
//
// UpdateUserShareRole.swift
// Proton Pass - Created on 04/08/2023.
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

import Client
import Entities

public protocol UpdateUserShareRoleUseCase: Sendable {
    func execute(userShareId: String, shareId: String, shareRole: ShareRole, expireTime: Int?) async throws
}

public extension UpdateUserShareRoleUseCase {
    func callAsFunction(userShareId: String,
                        shareId: String,
                        shareRole: ShareRole,
                        expireTime: Int? = nil) async throws {
        try await execute(userShareId: userShareId, shareId: shareId, shareRole: shareRole, expireTime: expireTime)
    }
}

public final class UpdateUserShareRole: UpdateUserShareRoleUseCase {
    private let repository: any ShareRepositoryProtocol

    public init(repository: any ShareRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(userShareId: String,
                        shareId: String,
                        shareRole: ShareRole,
                        expireTime: Int?) async throws {
        try await repository.updateUserPermission(userId: userShareId,
                                                  shareId: shareId,
                                                  shareRole: shareRole,
                                                  expireTime: expireTime)
    }
}
