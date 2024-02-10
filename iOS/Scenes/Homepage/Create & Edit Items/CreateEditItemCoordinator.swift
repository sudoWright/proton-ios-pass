//
// CreateEditItemCoordinator.swift
// Proton Pass - Created on 10/05/2023.
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
import Factory
import ProtonCoreLogin
import SwiftUI
import UIKit

@MainActor
protocol CreateEditItemCoordinatorDelegate: AnyObject {
    func createEditItemCoordinatorWantsToPresent(view: any View, dismissable: Bool)
}

typealias CreateEditItemDelegates =
    CreateEditItemViewModelDelegate &
    CreateEditLoginViewModelDelegate &
    GeneratePasswordCoordinatorDelegate &
    GeneratePasswordViewModelDelegate

@MainActor
final class CreateEditItemCoordinator: DeinitPrintable {
    deinit { print(deinitMessage) }

    private let upgradeChecker = resolve(\SharedServiceContainer.upgradeChecker)
    private let vaultsManager = resolve(\SharedServiceContainer.vaultsManager)
    private let getCurrentSelectedShareId = resolve(\SharedUseCasesContainer.getCurrentSelectedShareId)

    private weak var createEditItemDelegates: CreateEditItemDelegates?

    private var currentViewModel: BaseCreateEditItemViewModel?
    private var generatePasswordCoordinator: GeneratePasswordCoordinator?

    weak var delegate: CreateEditItemCoordinatorDelegate?

    init(createEditItemDelegates: CreateEditItemDelegates?) {
        self.createEditItemDelegates = createEditItemDelegates
    }
}

// MARK: - Public APIs

extension CreateEditItemCoordinator {
    /// Refresh currently shown create edit page
    func refresh() {
        currentViewModel?.refresh()
    }

    func presentEditItemView(for itemContent: ItemContent) throws {
        let mode = ItemMode.edit(itemContent)
        switch itemContent.contentData.type {
        case .login:
            try presentCreateEditLoginView(mode: mode)
        case .note:
            try presentCreateEditNoteView(mode: mode)
        case .creditCard:
            try presentCreateEditCreditCardView(mode: mode)
        case .alias:
            try presentCreateEditAliasView(mode: mode)
        }
    }

    @MainActor
    func presentCreateItemView(for itemType: ItemType) async throws {
        guard let shareId = await getCurrentSelectedShareId() else { return }
        switch itemType {
        case .login:
            let logInType = ItemCreationType.login(title: nil, url: nil, note: nil, autofill: false)
            try presentCreateEditLoginView(mode: .create(shareId: shareId, type: logInType))
        case .alias:
            try presentCreateEditAliasView(mode: .create(shareId: shareId, type: .alias))
        case .creditCard:
            try presentCreateEditCreditCardView(mode: .create(shareId: shareId, type: .other))
        case .note:
            try presentCreateEditNoteView(mode: .create(shareId: shareId, type: .other))
        case .password:
            presentGeneratePasswordView(mode: .random,
                                        generatePasswordViewModelDelegate: createEditItemDelegates)
        }
    }

    func presentGeneratePasswordForLoginItem(delegate: GeneratePasswordViewModelDelegate) {
        presentGeneratePasswordView(mode: .createLogin, generatePasswordViewModelDelegate: delegate)
    }
}

// MARK: - Private APIs

private extension CreateEditItemCoordinator {
    func present(_ view: any View, dismissable: Bool) {
        assert(delegate != nil, "delegate is not set")
        delegate?.createEditItemCoordinatorWantsToPresent(view: view, dismissable: dismissable)
    }

    func presentCreateEditLoginView(mode: ItemMode) throws {
        let viewModel = try CreateEditLoginViewModel(mode: mode,
                                                     upgradeChecker: upgradeChecker,
                                                     vaults: vaultsManager.getAllVaults())
        viewModel.delegate = createEditItemDelegates
        viewModel.createEditLoginViewModelDelegate = createEditItemDelegates
        let view = CreateEditLoginView(viewModel: viewModel)
        present(view, dismissable: false)
        currentViewModel = viewModel
    }

    func presentCreateEditAliasView(mode: ItemMode) throws {
        let viewModel = try CreateEditAliasViewModel(mode: mode,
                                                     upgradeChecker: upgradeChecker,
                                                     vaults: vaultsManager.getAllVaults())
        viewModel.delegate = createEditItemDelegates
        let view = CreateEditAliasView(viewModel: viewModel)
        present(view, dismissable: false)
        currentViewModel = viewModel
    }

    func presentCreateEditCreditCardView(mode: ItemMode) throws {
        let viewModel = try CreateEditCreditCardViewModel(mode: mode,
                                                          upgradeChecker: upgradeChecker,
                                                          vaults: vaultsManager.getAllVaults())
        viewModel.delegate = createEditItemDelegates
        let view = CreateEditCreditCardView(viewModel: viewModel)
        present(view, dismissable: false)
        currentViewModel = viewModel
    }

    func presentCreateEditNoteView(mode: ItemMode) throws {
        let viewModel = try CreateEditNoteViewModel(mode: mode,
                                                    upgradeChecker: upgradeChecker,
                                                    vaults: vaultsManager.getAllVaults())
        viewModel.delegate = createEditItemDelegates
        let view = CreateEditNoteView(viewModel: viewModel)
        present(view, dismissable: false)
        currentViewModel = viewModel
    }

    func presentGeneratePasswordView(mode: GeneratePasswordViewMode,
                                     generatePasswordViewModelDelegate: GeneratePasswordViewModelDelegate?) {
        assert(delegate != nil, "delegate is not set")
        guard delegate != nil else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let coordinator =
                GeneratePasswordCoordinator(generatePasswordViewModelDelegate: generatePasswordViewModelDelegate,
                                            mode: mode)
            coordinator.delegate = createEditItemDelegates
            coordinator.start()
            generatePasswordCoordinator = coordinator
        }
    }
}
