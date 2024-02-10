//
// ShareCoordinator.swift
// Proton Pass - Created on 22/01/2024.
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

import Client
import Combine
import Core
import DesignSystem
import Entities
import Factory
import Macro
import Screens
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SharedContent {
    case url(URL)
    case text(String)
    case textWithUrl(String, URL)
    case unknown

    var url: URL? {
        switch self {
        case let .url(url): url
        case let .textWithUrl(_, url): url
        default: nil
        }
    }

    var note: String {
        switch self {
        case let .url(url): url.absoluteString
        case let .text(text): text
        case let .textWithUrl(text, _): text
        case .unknown: ""
        }
    }

    func title(for type: SharedItemType) -> String {
        guard case let .url(url) = self else { return "" }
        let urlString = url.absoluteString
        return switch type {
        case .note: #localized("Note for %@", urlString)
        case .login: #localized("Login for %@", urlString)
        }
    }
}

enum SharedItemType: CaseIterable {
    case note, login
}

@MainActor
final class ShareCoordinator {
    private let apiManager = resolve(\SharedToolingContainer.apiManager)
    private let credentialProvider = resolve(\SharedDataContainer.credentialProvider)
    private let setUpSentry = resolve(\SharedUseCasesContainer.setUpSentry)
    private let theme = resolve(\SharedToolingContainer.theme)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let sendErrorToSentry = resolve(\SharedUseCasesContainer.sendErrorToSentry)
    private let wipeAllData = resolve(\SharedUseCasesContainer.wipeAllData)
    private let corruptedSessionEventStream = resolve(\SharedDataStreamContainer.corruptedSessionEventStream)

    @LazyInjected(\SharedServiceContainer.vaultsManager) private var vaultsManager
    @LazyInjected(\SharedUseCasesContainer.getMainVault) private var getMainVault
    @LazyInjected(\SharedServiceContainer.upgradeChecker) private var upgradeChecker
    @LazyInjected(\SharedViewContainer.bannerManager) private var bannerManager
    @LazyInjected(\SharedUseCasesContainer.revokeCurrentSession) private var revokeCurrentSession

    private var lastChildViewController: UIViewController?
    private weak var rootViewController: UIViewController?
    private var createEditItemViewModel: BaseCreateEditItemViewModel?
    private var customCoordinator: CustomCoordinator?
    private var generatePasswordCoordinator: GeneratePasswordCoordinator?

    private var cancellables = Set<AnyCancellable>()

    private var context: NSExtensionContext? { rootViewController?.extensionContext }
    private var topMostViewController: UIViewController? { rootViewController?.topMostViewController }

    init(rootViewController: UIViewController) {
        SharedViewContainer.shared.register(rootViewController: rootViewController)
        self.rootViewController = rootViewController
        AppearanceSettings.apply()
        setUpSentry(bundle: .main)
        setUpRouter()

        apiManager.sessionWasInvalidated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionUID in
                guard let self else { return }
                logOut(error: PassError.unexpectedLogout, sessionId: sessionUID)
            }
            .store(in: &cancellables)

        corruptedSessionEventStream
            .removeDuplicates()
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reason in
                guard let self else { return }
                logOut(error: PassError.corruptedSession(reason), sessionId: reason.sessionId)
            }
            .store(in: &cancellables)
    }
}

// MARK: Public APIs

extension ShareCoordinator {
    func start() async {
        if credentialProvider.isAuthenticated {
            await parseSharedContentAndBeginShareFlow()
        } else {
            showNotLoggedInView()
        }
    }
}

// MARK: Private APIs

private extension ShareCoordinator {
    func setUpRouter() {
        router
            .newSheetDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                guard let self else { return }
                switch destination {
                case let .mailboxView(selection, _):
                    presentMailboxSelection(selection)
                case let .suffixView(selection):
                    presentSuffixSelection(selection)
                case .vaultSelection:
                    presentVaultSelector()
                default:
                    break
                }
            }
            .store(in: &cancellables)

        router
            .globalElementDisplay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                guard let self else { return }
                switch destination {
                case let .globalLoading(shouldShow):
                    if shouldShow {
                        showLoadingHud()
                    } else {
                        hideLoadingHud()
                    }
                case let .displayErrorBanner(error):
                    bannerManager.displayTopErrorMessage(error)
                default:
                    return
                }
            }
            .store(in: &cancellables)
    }

    func showNotLoggedInView() {
        let view = NotLoggedInView(variant: .shareExtension) { [weak self] in
            guard let self else { return }
            dismissExtension()
        }
        .theme(theme)
        showView(view)
    }

    func parseSharedContent() async throws -> SharedContent {
        guard let extensionItems = context?.inputItems as? [NSExtensionItem] else {
            assertionFailure("Failed to cast inputItems into NSExtensionItems")
            return .unknown
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for attachment in attachments {
                // Optionally parse URL and fallback to text
                if let url = try? await attachment.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    return .url(url)
                }

                if let text = try await attachment
                    .loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    if let url = text.firstUrl() {
                        return .textWithUrl(text, url)
                    } else {
                        return .text(text)
                    }
                }
            }
        }

        return .unknown
    }

    func parseSharedContentAndBeginShareFlow() async {
        do {
            let content = try await parseSharedContent()
            let view = SharedContentView(content: content,
                                         onCreate: { [weak self] type in
                                             guard let self else { return }
                                             presentCreateItemView(for: type, content: content)
                                         },
                                         onDismiss: { [weak self] in
                                             guard let self else { return }
                                             dismissExtension()
                                         })
                                         .localAuthentication(delayed: false,
                                                              onAuth: {},
                                                              onSuccess: {},
                                                              onFailure: { [weak self] in
                                                                  guard let self else { return }
                                                                  logOut()
                                                              })
            showView(view)
        } catch {
            alert(error: error) { [weak self] in
                guard let self else { return }
                dismissExtension()
            }
        }
    }

    func presentCreateItemView(for type: SharedItemType, content: SharedContent) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if vaultsManager.getAllVaultContents().isEmpty {
                    try await vaultsManager.asyncRefresh()
                }
                let shareId = await getMainVault()?.shareId ?? ""
                let vaults = vaultsManager.getAllVaults()
                let title = content.title(for: type)

                let viewController: UIViewController
                switch type {
                case .note:
                    let creationType = ItemCreationType.note(title: title, note: content.note)
                    let viewModel = try CreateEditNoteViewModel(mode: .create(shareId: shareId,
                                                                              type: creationType),
                                                                upgradeChecker: upgradeChecker,
                                                                vaults: vaults)
                    viewModel.delegate = self
                    createEditItemViewModel = viewModel
                    let view = CreateEditNoteView(viewModel: viewModel)
                    viewController = UIHostingController(rootView: view)
                case .login:
                    let urlString = content.url?.absoluteString
                    let creationType = ItemCreationType.login(title: title,
                                                              url: urlString,
                                                              note: content.note,
                                                              autofill: false)
                    let viewModel =
                        try CreateEditLoginViewModel(mode: .create(shareId: shareId, type: creationType),
                                                     upgradeChecker: upgradeChecker, vaults: vaults)
                    viewModel.delegate = self
                    viewModel.createEditLoginViewModelDelegate = self
                    createEditItemViewModel = viewModel
                    let view = CreateEditLoginView(viewModel: viewModel)
                    viewController = UIHostingController(rootView: view)
                }
                rootViewController?.present(viewController, animated: true)
            } catch {
                alert(error: error) { [weak self] in
                    guard let self else { return }
                    dismissExtension()
                }
            }
        }
    }

    func presentVaultSelector() {
        guard let topMostViewController else { return }
        let view = VaultSelectorView(viewModel: .init())
        let viewController = UIHostingController(rootView: view)

        let customHeight = 66 * vaultsManager.getVaultCount() + 180 // Space for upsell banner
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: topMostViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        topMostViewController.present(viewController, animated: true)
    }

    func dismissExtension() {
        context?.completeRequest(returningItems: nil)
    }

    func logOut(error: Error? = nil,
                sessionId: String? = nil,
                completion: (() -> Void)? = nil) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                sendErrorToSentry(error, sessionId: sessionId)
            }
            await revokeCurrentSession()
            await wipeAllData(isTests: false)
            showNotLoggedInView()
            completion?()
        }
    }
}

// MARK: Create alias

extension ShareCoordinator {
    func presentMailboxSelection(_ mailboxSelection: MailboxSelection) {
        guard let rootViewController else { return }
        let viewModel = MailboxSelectionViewModel(mailboxSelection: mailboxSelection,
                                                  mode: .createAliasLite,
                                                  titleMode: .create)
        let view = MailboxSelectionView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * mailboxSelection.mailboxes.count + 150
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        topMostViewController?.present(viewController, animated: true)
    }

    func presentSuffixSelection(_ suffixSelection: SuffixSelection) {
        guard let rootViewController else { return }
        let viewModel = SuffixSelectionViewModel(suffixSelection: suffixSelection)
        let view = SuffixSelectionView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * suffixSelection.suffixes.count + 100
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        topMostViewController?.present(viewController, animated: true)
    }
}

// MARK: ExtensionCoordinator

extension ShareCoordinator: ExtensionCoordinator {
    func getRootViewController() -> UIViewController? {
        rootViewController
    }

    func getLastChildViewController() -> UIViewController? {
        lastChildViewController
    }

    func setLastChildViewController(_ viewController: UIViewController) {
        lastChildViewController = viewController
    }
}

// MARK: CreateEditItemViewModelDelegate

extension ShareCoordinator: CreateEditItemViewModelDelegate {
    func createEditItemViewModelWantsToAddCustomField(delegate: CustomFieldAdditionDelegate) {
        guard let topMostViewController else { return }
        customCoordinator = CustomFieldAdditionCoordinator(rootViewController: topMostViewController,
                                                           delegate: delegate)
        customCoordinator?.start()
    }

    func createEditItemViewModelWantsToEditCustomFieldTitle(_ uiModel: CustomFieldUiModel,
                                                            delegate: CustomFieldEditionDelegate) {
        guard let rootViewController else { return }
        customCoordinator = CustomFieldEditionCoordinator(rootViewController: rootViewController,
                                                          delegate: delegate,
                                                          uiModel: uiModel)
        customCoordinator?.start()
    }

    func createEditItemViewModelDidCreateItem(_ item: SymmetricallyEncryptedItem, type: ItemContentType) {
        let alert = UIAlertController(title: type.creationMessage, message: nil, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: #localized("Close"), style: .default) { [weak self] _ in
            guard let self else { return }
            dismissExtension()
        }
        alert.addAction(closeAction)
        topMostViewController?.present(alert, animated: true)
    }

    func createEditItemViewModelDidUpdateItem(_ type: Entities.ItemContentType, updated: Bool) {
        // Not applicable
    }
}

// MARK: CreateEditLoginViewModelDelegate

extension ShareCoordinator: CreateEditLoginViewModelDelegate {
    func createEditLoginViewModelWantsToGenerateAlias(options: AliasOptions,
                                                      creationInfo: AliasCreationLiteInfo,
                                                      delegate: AliasCreationLiteInfoDelegate) {
        let viewModel = CreateAliasLiteViewModel(options: options, creationInfo: creationInfo)
        viewModel.aliasCreationDelegate = delegate
        let view = CreateAliasLiteView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        viewController.sheetPresentationController?.detents = [.medium()]
        viewController.sheetPresentationController?.prefersGrabberVisible = true
        topMostViewController?.present(viewController, animated: true)
    }

    func createEditLoginViewModelWantsToGeneratePassword(_ delegate: GeneratePasswordViewModelDelegate) {
        let coordinator = GeneratePasswordCoordinator(generatePasswordViewModelDelegate: delegate,
                                                      mode: .createLogin)
        coordinator.delegate = self
        coordinator.start()
        generatePasswordCoordinator = coordinator
    }
}

// MARK: GeneratePasswordCoordinatorDelegate

extension ShareCoordinator: GeneratePasswordCoordinatorDelegate {
    func generatePasswordCoordinatorWantsToPresent(viewController: UIViewController) {
        topMostViewController?.present(viewController, animated: true)
    }
}
