//
// TrashCoordinator.swift
// Proton Pass - Created on 07/07/2022.
// Copyright (c) 2022 Proton Technologies AG
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
import CryptoKit
import ProtonCore_Login
import SwiftUI
import UIComponents

final class TrashCoordinator: Coordinator {
    private let symmetricKey: SymmetricKey
    private let shareRepository: ShareRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol
    private let trashViewModel: TrashViewModel

    weak var bannerManager: BannerManager?
    var onRestoredItem: (() -> Void)?

    init(symmetricKey: SymmetricKey,
         shareRepository: ShareRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol) {
        self.symmetricKey = symmetricKey
        self.shareRepository = shareRepository
        self.itemRepository = itemRepository
        self.trashViewModel = TrashViewModel(symmetricKey: symmetricKey,
                                             shareRepository: shareRepository,
                                             itemRepository: itemRepository)
        super.init()
        self.start()
    }

    private func start() {
        trashViewModel.delegate = self
        start(with: TrashView(viewModel: trashViewModel))
    }

    func refreshTrashedItems() {
        trashViewModel.fetchAllTrashedItems(forceRefresh: false)
    }
}

// MARK: - MyVaultsCoordinatorDelegate
extension TrashCoordinator: MyVaultsCoordinatorDelegate {
    func myVaultsCoordinatorWantsToRefreshTrash() {
        refreshTrashedItems()
    }
}

// MARK: - TrashViewModelDelegate
extension TrashCoordinator: TrashViewModelDelegate {
    func trashViewModelWantsToToggleSidebar() {
        toggleSidebar()
    }

    func trashViewModelWantsToShowOptions(for item: ItemListUiModel) {
        let optionsView = TrashedItemOptionsView(item: item, delegate: self)
        let optionsViewController = UIHostingController(rootView: optionsView)
        optionsViewController.sheetPresentationController?.detents = [.medium()]
        presentViewController(optionsViewController)
    }

    func trashViewModelDidRestoreItem(_ type: Client.ItemContentType) {
        dismissTopMostViewController { [unowned self] in
            let message: String
            switch type {
            case .alias: message = "Alias restored"
            case .login: message = "Login restored"
            case .note: message = "Note restored"
            }
            self.bannerManager?.displayBottomInfoMessage(message)
            self.onRestoredItem?()
        }
    }

    func trashViewModelDidRestoreAllItems(count: Int) {
        dismissTopMostViewController { [unowned self] in
            self.bannerManager?.displayBottomInfoMessage("\(count) item(s) restored")
            self.onRestoredItem?()
        }
    }

    func trashViewModelDidDeleteItem(_ type: Client.ItemContentType) {
        dismissTopMostViewController { [unowned self] in
            let message: String
            switch type {
            case .alias: message = "Alias permanently deleted"
            case .login: message = "Login permanently deleted"
            case .note: message = "Note permanently deleted"
            }
            self.bannerManager?.displayBottomInfoMessage(message)
        }
    }

    func trashViewModelDidEmptyTrash() {
        bannerManager?.displayBottomInfoMessage("Trash emptied")
    }

    func trashViewModelDidFail(_ error: Error) {
        bannerManager?.displayTopErrorMessage(error)
    }
}

// MARK: - TrashedItemOptionsViewDelegate
extension TrashCoordinator: TrashedItemOptionsViewDelegate {
    func trashedItemWantsToBeRestored(_ item: ItemListUiModel) {
        trashViewModel.restore(item)
    }

    func trashedItemWantsToShowDetail(_ item: ItemListUiModel) {
        print(#function)
    }

    func trashedItemWantsToBeDeletedPermanently(_ item: ItemListUiModel) {
        trashViewModel.deletePermanently(item)
    }
}
