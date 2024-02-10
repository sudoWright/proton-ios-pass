//
// CopyTotpTokenAndNotify.swift
// Proton Pass - Created on 31/07/2023.
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
import Macro
import UserNotifications

protocol CopyTotpTokenAndNotifyUseCase: Sendable {
    func execute(itemContent: ItemContent, clipboardManager: ClipboardManagerProtocol) async throws
}

extension CopyTotpTokenAndNotifyUseCase {
    func callAsFunction(itemContent: ItemContent,
                        clipboardManager: ClipboardManagerProtocol) async throws {
        try await execute(itemContent: itemContent, clipboardManager: clipboardManager)
    }
}

final class CopyTotpTokenAndNotify: @unchecked Sendable, CopyTotpTokenAndNotifyUseCase {
    private let preferences: Preferences
    private let logger: Logger
    private let generateTotpToken: GenerateTotpTokenUseCase
    private let notificationService: LocalNotificationServiceProtocol
    private let upgradeChecker: UpgradeCheckerProtocol

    init(preferences: Preferences,
         logManager: LogManagerProtocol,
         generateTotpToken: GenerateTotpTokenUseCase,
         notificationService: LocalNotificationServiceProtocol,
         upgradeChecker: UpgradeCheckerProtocol) {
        self.preferences = preferences
        logger = .init(manager: logManager)
        self.generateTotpToken = generateTotpToken
        self.notificationService = notificationService
        self.upgradeChecker = upgradeChecker
    }

    @MainActor
    func execute(itemContent: ItemContent, clipboardManager: ClipboardManagerProtocol) async throws {
        guard preferences.automaticallyCopyTotpCode else {
            // Not opted in
            return
        }

        guard try await upgradeChecker.canShowTOTPToken(creationDate: itemContent.item.createTime) else {
            // Current plan does not allow
            return
        }

        guard case let .login(data) = itemContent.contentData else {
            // Not a login item
            let error = PassError.credentialProvider(.notLogInItem)
            logger.error(error)
            throw error
        }

        guard !data.totpUri.isEmpty else {
            // No URI
            return
        }
        let totpData = try generateTotpToken(uri: data.totpUri)
        clipboardManager.copy(text: totpData.code, bannerMessage: "")
        logger.trace("Copied TOTP token \(itemContent.debugDescription)")

        let content = UNMutableNotificationContent()
        content.title = #localized("TOTP copied")
        content.subtitle = itemContent.name
        content.body = """
        "\(totpData.code)" is copied to clipboard.
        Expiring in \(totpData.timerData.remaining) seconds.
        """

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil) // Deliver immediately
        // There seems to be a 5 second limit to autofill extension.
        // if the delay goes above it stops working and doesn't remove the notification
        let delay = min(totpData.timerData.remaining, 5)
        notificationService.addWithTimer(for: request, and: Double(delay))
    }
}
