//
// BannerManager.swift
// Proton Pass - Created on 13/03/2023.
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

import Entities
import Macro
import ProtonCoreUIFoundations
import UIKit

public protocol BannerDisplayProtocol: Sendable {
    func displayBottomSuccessMessage(_ message: String)

    func displayBottomInfoMessage(_ message: String,
                                  dismissButtonTitle: String,
                                  onDismiss: @escaping (@Sendable (PMBanner) -> Void))

    func displayBottomInfoMessage(_ message: String)
    func displayTopErrorMessage(_ message: String,
                                dismissButtonTitle: String,
                                onDismiss: (@Sendable (PMBanner) -> Void)?)

    func displayTopErrorMessage(_ error: any Error)
}

public extension BannerDisplayProtocol {
    func displayTopErrorMessage(_ message: String,
                                dismissButtonTitle: String = #localized("OK"),
                                onDismiss: (@Sendable (PMBanner) -> Void)? = nil) {
        displayTopErrorMessage(message, dismissButtonTitle: dismissButtonTitle, onDismiss: onDismiss)
    }
}

extension PMBanner: @unchecked Sendable {}
extension PMBannerPosition: @unchecked Sendable {}
extension PMBannerNewStyle: @unchecked Sendable {}

public final class BannerManager: @unchecked Sendable, BannerDisplayProtocol {
    private weak var container: UIViewController?

    public init(container: UIViewController?) {
        self.container = container
    }

    private func display(message: String, at position: PMBannerPosition, style: PMBannerNewStyle) {
        guard let container else {
            return
        }
        Task { @MainActor in
            let banner = PMBanner(message: message, style: style)
            banner.show(at: position, on: container.topMostViewController)
        }
    }

    public func displayBottomSuccessMessage(_ message: String) {
        display(message: message, at: .bottom, style: .success)
    }

    public func displayBottomInfoMessage(_ message: String,
                                         dismissButtonTitle: String,
                                         onDismiss: @escaping (@Sendable (PMBanner) -> Void)) {
        guard let container else {
            return
        }

        Task { @MainActor in
            let banner = PMBanner(message: message, style: PMBannerNewStyle.info)
            banner.addButton(text: dismissButtonTitle, handler: onDismiss)
            banner.show(at: .bottom, on: container.topMostViewController)
        }
    }

    public func displayBottomInfoMessage(_ message: String) {
        display(message: message, at: .bottom, style: .info)
    }

    public func displayTopErrorMessage(_ message: String,
                                       dismissButtonTitle: String = #localized("OK"),
                                       onDismiss: (@Sendable (PMBanner) -> Void)? = nil) {
        guard let container else {
            return
        }

        Task { @MainActor in
            let onDismiss = onDismiss ?? { banner in
                Task {
                    await banner.dismiss()
                }
            }
            let banner = PMBanner(message: message, style: PMBannerNewStyle.error)
            banner.addButton(text: dismissButtonTitle, handler: onDismiss)
            banner.show(at: .top, on: container.topMostViewController)
        }
    }

    public func displayTopErrorMessage(_ error: some Error) {
        let message = if let passError = error as? PassError {
            passError.localizedDebugDescription
        } else {
            error.localizedDescription
        }
        displayTopErrorMessage(message)
    }
}
