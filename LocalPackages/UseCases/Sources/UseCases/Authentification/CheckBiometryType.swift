//
// CheckBiometryType.swift
// Proton Pass - Created on 13/07/2023.
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

@preconcurrency import LocalAuthentication

/// Determine the supported `LABiometryType` of the device
public protocol CheckBiometryTypeUseCase: Sendable {
    func execute(policy: LAPolicy) throws -> LABiometryType
}

public extension CheckBiometryTypeUseCase {
    func callAsFunction(policy: LAPolicy) throws -> LABiometryType {
        try execute(policy: policy)
    }
}

public final class CheckBiometryType: CheckBiometryTypeUseCase {
    private let context = LAContext()

    public init() {}

    public func execute(policy: LAPolicy) throws -> LABiometryType {
        var error: NSError?
        context.canEvaluatePolicy(policy, error: &error)
        if let error {
            throw error
        } else {
            return context.biometryType
        }
    }
}
