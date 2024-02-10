//
// AddTelemetryEvent.swift
// Proton Pass - Created on 02/08/2023.
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
import Core
import Entities

public protocol AddTelemetryEventUseCase: Sendable {
    func execute(with eventType: TelemetryEventType)
    func execute(with eventTypes: [TelemetryEventType])
}

public extension AddTelemetryEventUseCase {
    func callAsFunction(with eventType: TelemetryEventType) {
        execute(with: eventType)
    }

    func callAsFunction(with eventTypes: [TelemetryEventType]) {
        execute(with: eventTypes)
    }
}

public final class AddTelemetryEvent: @unchecked Sendable, AddTelemetryEventUseCase {
    private let repository: any TelemetryEventRepositoryProtocol
    private let logger: Logger

    public init(repository: any TelemetryEventRepositoryProtocol,
                logManager: any LogManagerProtocol) {
        self.repository = repository
        logger = .init(manager: logManager)
    }

    public func execute(with eventType: TelemetryEventType) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.addNewEvent(type: eventType)
            } catch {
                logger.error(error)
            }
        }
    }

    public func execute(with eventTypes: [TelemetryEventType]) {
        Task { [weak self] in
            guard let self else { return }
            do {
                for event in eventTypes {
                    try await repository.addNewEvent(type: event)
                }
            } catch {
                logger.error(error)
            }
        }
    }
}
