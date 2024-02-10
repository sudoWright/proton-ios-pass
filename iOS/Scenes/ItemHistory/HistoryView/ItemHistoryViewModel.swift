//
//
// ItemHistoryViewModel.swift
// Proton Pass - Created on 09/01/2024.
// Copyright (c) 2024 Proton Technologies AG
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

import Entities
import Factory
import Foundation

@MainActor
final class ItemHistoryViewModel: ObservableObject, Sendable {
    @Published private(set) var lastUsedTime: String?
    @Published private(set) var history = [ItemContent]()
    @Published private(set) var loading = true

    let item: ItemContent
    private let getItemHistory = resolve(\UseCasesContainer.getItemHistory)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private var canLoadMoreItems = true
    private var currentTask: Task<Void, Never>?
    private var lastToken: String?

    init(item: ItemContent) {
        self.item = item
        lastUsedTime = item.lastAutoFilledDate
        setUp()
    }

    deinit {
        currentTask?.cancel()
        currentTask = nil
    }

    func loadItemHistory() {
        guard canLoadMoreItems, currentTask == nil else {
            return
        }
        loading = true

        currentTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                loading = false
                currentTask = nil
            }
            do {
                let items = try await getItemHistory(shareId: item.shareId,
                                                     itemId: item.itemId,
                                                     lastToken: lastToken)

                history.append(contentsOf: items.data)
                guard items.lastToken != nil else {
                    canLoadMoreItems = false
                    return
                }
                lastToken = items.lastToken
            } catch {
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func isCreationRevision(_ currentItem: ItemContent) -> Bool {
        currentItem.item.revision == 1
    }

    func isCurrentRevision(_ currentItem: ItemContent) -> Bool {
        currentItem.item.revision == item.item.revision
    }

    func loadMoreContentIfNeeded(item: ItemContent) {
        guard let lastItem = history.last,
              lastItem.item.revision == item.item.revision else {
            return
        }
        loadItemHistory()
    }
}

private extension ItemHistoryViewModel {
    func setUp() {
        loadItemHistory()
    }
}
