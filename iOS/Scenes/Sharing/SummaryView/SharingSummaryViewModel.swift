//
//
// SharingSummaryViewModel.swift
// Proton Pass - Created on 20/07/2023.
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
import Factory
import Foundation

@MainActor
final class SharingSummaryViewModel: ObservableObject, Sendable {
    @Published private(set) var infos = [SharingInfos]()
    @Published private(set) var sendingInvite = false

    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private var lastTask: Task<Void, Never>?
    private let getShareInviteInfos = resolve(\UseCasesContainer.getCurrentShareInviteInformations)
    private let sendShareInvite = resolve(\UseCasesContainer.sendVaultShareInvite)

    init() {
        setUp()
    }

    var hasSingleInvite: Bool {
        infos.count == 1
    }

    func sendInvite() {
        lastTask?.cancel()
        lastTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                self.sendingInvite = false
                self.lastTask?.cancel()
                self.lastTask = nil
            }
            sendingInvite = true

            do {
                if Task.isCancelled {
                    return
                }
                let sharedVault = try await sendShareInvite(with: infos)
                if let baseInfo = infos.first {
                    switch baseInfo.vault {
                    case .existing:
                        // When sharing a created vault, we want to keep the context
                        // by only dismissing the top most sheet (which is share vault sheet)
                        router.present(for: .manageShareVault(sharedVault, .topMost))
                    case .new:
                        // When sharing a new vault from item detail page,
                        // as the item is moved to the new vault, the last item detail sheet is stale
                        // so we dismiss all sheets
                        router.present(for: .manageShareVault(sharedVault, .all))
                    }
                }
            } catch {
                router.display(element: .displayErrorBanner(error))
            }
        }
    }
}

private extension SharingSummaryViewModel {
    func setUp() {
        infos = getShareInviteInfos()
    }
}
