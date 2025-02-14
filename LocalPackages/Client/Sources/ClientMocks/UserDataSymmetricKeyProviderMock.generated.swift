// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// Proton Pass.
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

    import Client
import Combine
import Entities
import CryptoKit
import ProtonCoreLogin

public final class UserDataSymmetricKeyProviderMock: @unchecked Sendable, SymmetricKeyProvider, UserDataProvider {

    public init() {}

    // MARK: - ⚡️ SymmetricKeyProvider
    // MARK: - getSymmetricKey
    public var getSymmetricKeyThrowableError1: Error?
    public var closureGetSymmetricKey: () -> () = {}
    public var invokedGetSymmetricKeyfunction = false
    public var invokedGetSymmetricKeyCount = 0
    public var stubbedGetSymmetricKeyResult: SymmetricKey!

    public func getSymmetricKey() throws -> SymmetricKey {
        invokedGetSymmetricKeyfunction = true
        invokedGetSymmetricKeyCount += 1
        if let error = getSymmetricKeyThrowableError1 {
            throw error
        }
        closureGetSymmetricKey()
        return stubbedGetSymmetricKeyResult
    }
    // MARK: - removeSymmetricKey
    public var closureRemoveSymmetricKey: () -> () = {}
    public var invokedRemoveSymmetricKeyfunction = false
    public var invokedRemoveSymmetricKeyCount = 0

    public func removeSymmetricKey() {
        invokedRemoveSymmetricKeyfunction = true
        invokedRemoveSymmetricKeyCount += 1
        closureRemoveSymmetricKey()
    }
    // MARK: - ⚡️ UserDataProvider
    // MARK: - getUserData
    public var closureGetUserData: () -> () = {}
    public var invokedGetUserDatafunction = false
    public var invokedGetUserDataCount = 0
    public var stubbedGetUserDataResult: UserData?

    public func getUserData() -> UserData? {
        invokedGetUserDatafunction = true
        invokedGetUserDataCount += 1
        closureGetUserData()
        return stubbedGetUserDataResult
    }
    // MARK: - setUserData
    public var closureSetUserData: () -> () = {}
    public var invokedSetUserDatafunction = false
    public var invokedSetUserDataCount = 0
    public var invokedSetUserDataParameters: (userData: UserData?, Void)?
    public var invokedSetUserDataParametersList = [(userData: UserData?, Void)]()

    public func setUserData(_ userData: UserData?) {
        invokedSetUserDatafunction = true
        invokedSetUserDataCount += 1
        invokedSetUserDataParameters = (userData, ())
        invokedSetUserDataParametersList.append((userData, ()))
        closureSetUserData()
    }
}
