//
// CredentialProviderCoordinator.swift
// Proton Pass - Created on 27/09/2022.
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

// swiftlint:disable file_length
import AuthenticationServices
import Client
import Core
import CoreData
import CryptoKit
import Factory
import MBProgressHUD
import ProtonCore_Authentication
import ProtonCore_CryptoGoImplementation
import ProtonCore_CryptoGoInterface
import ProtonCore_Keymaker
import ProtonCore_Login
import ProtonCore_Networking
import ProtonCore_Services
import SwiftUI
import UIComponents
import UserNotifications

public final class CredentialProviderCoordinator {
    /// Self-initialized properties
    private let apiManager: APIManager
    private let appData: AppData
    private let bannerManager: BannerManager
    private let clipboardManager: ClipboardManager
    private let container: NSPersistentContainer
    private let context: ASCredentialProviderExtensionContext
    private let credentialManager: CredentialManagerProtocol
    private let keymaker: Keymaker
    private let logManager: LogManager
    private let logger: Logger
    private let preferences: Preferences
    private let rootViewController: UIViewController
    private var notificationService: LocalNotificationServiceProtocol

    /// Derived properties
    private var lastChildViewController: UIViewController?
    private var symmetricKey: SymmetricKey?
    private var shareRepository: ShareRepositoryProtocol?
    private var shareEventIDRepository: ShareEventIDRepositoryProtocol?
    private var itemRepository: ItemRepositoryProtocol?
    private var favIconRepository: FavIconRepositoryProtocol?
    private var shareKeyRepository: ShareKeyRepositoryProtocol?
    private var aliasRepository: AliasRepositoryProtocol?
    private var remoteSyncEventsDatasource: RemoteSyncEventsDatasourceProtocol?
    private var telemetryEventRepository: TelemetryEventRepositoryProtocol?
    private var upgradeChecker: UpgradeCheckerProtocol?
    private var featureFlagsRepository: FeatureFlagsRepositoryProtocol?
    private var currentCreateEditItemViewModel: BaseCreateEditItemViewModel?
    private var credentialsViewModel: CredentialsViewModel?
    private var vaultListUiModels: [VaultListUiModel]?
    private var aliasCount: Int?
    private var vaultCount: Int?
    private var totpCount: Int?

    private var wordProvider: WordProviderProtocol?
    private var generatePasswordCoordinator: GeneratePasswordCoordinator?

    private var topMostViewController: UIViewController {
        rootViewController.topMostViewController
    }

    init(context: ASCredentialProviderExtensionContext, rootViewController: UIViewController) {
        injectDefaultCryptoImplementation()
        let keychain = PPKeychain()
        let keymaker = Keymaker(autolocker: Autolocker(lockTimeProvider: keychain), keychain: keychain)
        let logManager = LogManager(module: .autoFillExtension)
        let appVersion = "ios-pass-autofill-extension@\(Bundle.main.fullAppVersionName())"
        let appData = AppData(keychain: keychain, mainKeyProvider: keymaker, logManager: logManager)
        let preferences = Preferences()
        let apiManager = APIManager(logManager: logManager,
                                    appVer: appVersion,
                                    appData: appData,
                                    preferences: preferences)
        let bannerManager = BannerManager(container: rootViewController)

        self.apiManager = apiManager
        self.appData = appData
        self.bannerManager = bannerManager
        self.clipboardManager = .init(preferences: preferences)
        self.container = .Builder.build(name: kProtonPassContainerName, inMemory: false)
        self.context = context
        self.credentialManager = CredentialManager(logManager: logManager)
        self.keymaker = keymaker
        self.logManager = logManager
        self.logger = .init(manager: logManager)
        self.preferences = preferences
        self.notificationService = ServiceContainer.shared.notificationService()
        self.rootViewController = rootViewController

        // Post init
        self.clipboardManager.bannerManager = bannerManager
        self.makeSymmetricKeyAndRepositories()
        self.sendAllEventsIfApplicable()
        AppearanceSettings.apply()
    }

    func start(with serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        guard let userData = appData.userData else {
            showNotLoggedInView()
            return
        }

        do {
            let symmetricKey = try appData.getSymmetricKey()
            apiManager.sessionIsAvailable(authCredential: userData.credential,
                                          scopes: userData.scopes)
            showCredentialsView(userData: userData,
                                symmetricKey: symmetricKey,
                                serviceIdentifiers: serviceIdentifiers)
            addNewEvent(type: .autofillDisplay)
        } catch {
            alert(error: error)
        }
    }

    func configureExtension() {
        guard appData.userData != nil else {
            let view = NotLoggedInView(preferences: preferences) { [context] in
                context.completeExtensionConfigurationRequest()
            }
            showView(view)
            return
        }

        guard let itemRepository, let shareRepository, let upgradeChecker else { return }

        let viewModel = ExtensionSettingsViewModel(
            credentialManager: credentialManager,
            itemRepository: itemRepository,
            shareRepository: shareRepository,
            passPlanRepository: upgradeChecker.passPlanRepository,
            logManager: logManager,
            preferences: preferences,
            notificationService: notificationService)
        viewModel.delegate = self
        let view = ExtensionSettingsView(viewModel: viewModel)
        showView(view)
    }

    /// QuickType bar support
    func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        guard let itemRepository,
              let upgradeChecker,
              let recordIdentifier = credentialIdentity.recordIdentifier else {
            cancel(errorCode: .failed)
            return
        }

        if preferences.biometricAuthenticationEnabled {
            cancel(errorCode: .userInteractionRequired)
        } else {
            Task {
                do {
                    logger.trace("Autofilling from QuickType bar")
                    let ids = try AutoFillCredential.IDs.deserializeBase64(recordIdentifier)
                    if let itemContent = try await itemRepository.getItemContent(shareId: ids.shareId,
                                                                                 itemId: ids.itemId) {
                        if case .login(let data) = itemContent.contentData {
                            complete(quickTypeBar: true,
                                     credential: .init(user: data.username, password: data.password),
                                     itemContent: itemContent,
                                     itemRepository: itemRepository,
                                     upgradeChecker: upgradeChecker,
                                     serviceIdentifiers: [credentialIdentity.serviceIdentifier])
                        } else {
                            logger.error("Failed to autofill. Not log in item.")
                        }
                    } else {
                        logger.warning("Failed to autofill. Item not found.")
                        cancel(errorCode: .failed)
                    }
                } catch {
                    logger.error(error)
                    cancel(errorCode: .failed)
                }
            }
        }
    }

    // Biometric authentication
    func provideCredentialWithBiometricAuthentication(for credentialIdentity: ASPasswordCredentialIdentity) {
        guard let symmetricKey, let itemRepository, let upgradeChecker else {
            cancel(errorCode: .failed)
            return
        }

        let viewModel = LockedCredentialViewModel(itemRepository: itemRepository,
                                                  symmetricKey: symmetricKey,
                                                  credentialIdentity: credentialIdentity,
                                                  logManager: logManager)
        viewModel.onFailure = handle(error:)
        viewModel.onSuccess = { [unowned self] credential, itemContent in
            complete(quickTypeBar: false,
                     credential: credential,
                     itemContent: itemContent,
                     itemRepository: itemRepository,
                     upgradeChecker: upgradeChecker,
                     serviceIdentifiers: [credentialIdentity.serviceIdentifier])
        }
        showView(LockedCredentialView(preferences: preferences, viewModel: viewModel))
    }

    private func handle(error: Error) {
        let defaultHandler: (Error) -> Void = { [unowned self] error in
            self.logger.error(error)
            self.alert(error: error)
        }

        guard let error = error as? PPError,
              case .credentialProvider(let reason) = error else {
            defaultHandler(error)
            return
        }

        switch reason {
        case .userCancelled:
            cancel(errorCode: .userCanceled)
            return
        case .failedToAuthenticate:
            Task {
                defer { cancel(errorCode: .failed) }
                do {
                    logger.trace("Authenticaion failed. Removing all credentials")
                    appData.userData = nil
                    try await credentialManager.removeAllCredentials()
                    logger.info("Removed all credentials after authentication failure")
                } catch {
                    logger.error(error)
                }
            }
        default:
            defaultHandler(error)
        }
    }

    private func makeSymmetricKeyAndRepositories() {
        guard let userData = appData.userData,
              let symmetricKey = try? appData.getSymmetricKey() else { return }
        let apiService = apiManager.apiService

        let repositoryManager = RepositoryManager(apiService: apiService,
                                                  container: container,
                                                  currentDateProvider: CurrentDateProvider(),
                                                  limitationCounter: self,
                                                  logManager: logManager,
                                                  symmetricKey: symmetricKey,
                                                  userData: userData,
                                                  telemetryThresholdProvider: preferences)
        self.symmetricKey = symmetricKey
        self.shareRepository = repositoryManager.shareRepository
        self.shareEventIDRepository = repositoryManager.shareEventIDRepository

        let itemRepository = repositoryManager.itemRepository
        (itemRepository as? ItemRepository)?.delegate = credentialManager as? ItemRepositoryDelegate
        self.itemRepository = itemRepository
        self.favIconRepository = FavIconRepository(apiService: apiService,
                                                   containerUrl: URL.favIconsContainerURL(),
                                                   preferences: preferences,
                                                   symmetricKey: symmetricKey)
        self.shareKeyRepository = repositoryManager.shareKeyRepository
        self.aliasRepository = repositoryManager.aliasRepository
        self.remoteSyncEventsDatasource = repositoryManager.remoteSyncEventsDatasource
        self.telemetryEventRepository = repositoryManager.telemetryEventRepository
        self.upgradeChecker = repositoryManager.upgradeChecker
        self.featureFlagsRepository = repositoryManager.featureFlagsRepository
    }

    func addNewEvent(type: TelemetryEventType) {
        Task {
            do {
                try await telemetryEventRepository?.addNewEvent(type: type)
            } catch {
                logger.error(error)
            }
        }
    }

    func sendAllEventsIfApplicable() {
        Task {
            do {
                try await telemetryEventRepository?.sendAllEventsIfApplicable()
            } catch {
                logger.error(error)
            }
        }
    }
}

extension CredentialProviderCoordinator {
    private func updateRank(itemContent: ItemContent,
                            symmetricKey: SymmetricKey,
                            serviceIdentifiers: [ASCredentialServiceIdentifier],
                            lastUseTime: TimeInterval) async throws {
        if case .login(let data) = itemContent.contentData {
            let serviceUrls = serviceIdentifiers
                .map { serviceIdentifier in
                    switch serviceIdentifier.type {
                    case .URL:
                        return serviceIdentifier.identifier
                    case .domain:
                        return "https://\(serviceIdentifier.identifier)"
                    @unknown default:
                        return serviceIdentifier.identifier
                    }
                }
                .compactMap { URL(string: $0) }
            let itemUrls = data.urls.compactMap { URL(string: $0) }
            let matchedUrls = itemUrls.filter { itemUrl in
                serviceUrls.contains { serviceUrl in
                    if case .matched = URLUtils.Matcher.compare(itemUrl, serviceUrl) {
                        return true
                    }
                    return false
                }
            }

            let credentials = matchedUrls
                .map { AutoFillCredential(shareId: itemContent.shareId,
                                          itemId: itemContent.itemId,
                                          username: data.username,
                                          url: $0.absoluteString,
                                          lastUseTime: Int64(lastUseTime)) }
            try await credentialManager.insert(credentials: credentials)
        } else {
            throw PPError.credentialProvider(.notLogInItem)
        }
    }
}

// MARK: - Context actions
private extension CredentialProviderCoordinator {
    func cancel(errorCode: ASExtensionError.Code) {
        let error = NSError(domain: ASExtensionErrorDomain, code: errorCode.rawValue)
        context.cancelRequest(withError: error)
    }

    // swiftlint:disable:next function_parameter_count
    func complete(quickTypeBar: Bool,
                  credential: ASPasswordCredential,
                  itemContent: ItemContent,
                  itemRepository: ItemRepositoryProtocol,
                  upgradeChecker: UpgradeCheckerProtocol,
                  serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        Task { @MainActor in
            do {
                let getTotpData: () async -> TOTPData? = {
                    do {
                        if try await upgradeChecker.canShowTOTPToken(creationDate: itemContent.item.createTime) {
                            return try itemContent.totpData()
                        } else {
                            return nil
                        }
                    } catch {
                        self.logger.error(error)
                        return nil
                    }
                }

                if preferences.automaticallyCopyTotpCode, let totpData = await getTotpData() {
                    copyAndNotify(totpData: totpData)
                }

                context.completeRequest(withSelectedCredential: credential, completionHandler: nil)
                logger.info("Autofilled from QuickType bar \(quickTypeBar). \(itemContent.debugInformation)")

                let lastUseTime = Date().timeIntervalSince1970
                logger.trace("Updating rank \(itemContent.debugInformation)")
                try await updateRank(itemContent: itemContent,
                                     symmetricKey: itemRepository.symmetricKey,
                                     serviceIdentifiers: serviceIdentifiers,
                                     lastUseTime: lastUseTime)
                logger.info("Updated rank \(itemContent.debugInformation)")

                logger.trace("Updating lastUseTime \(itemContent.debugInformation)")
                try await itemRepository.update(item: itemContent, lastUseTime: lastUseTime)
                logger.info("Updated lastUseTime \(itemContent.debugInformation)")

                if quickTypeBar {
                    addNewEvent(type: .autofillTriggeredFromSource)
                } else {
                    addNewEvent(type: .autofillTriggeredFromApp)
                }
            } catch {
                logger.error(error)
                if quickTypeBar {
                    cancel(errorCode: .userInteractionRequired)
                } else {
                    alert(error: error)
                }
            }
        }
    }
        
    func copyAndNotify(totpData: TOTPData) {
        clipboardManager.copy(text: totpData.code, bannerMessage: "")
        let content = UNMutableNotificationContent()
        content.title = "Two Factor Authentication code copied"
        if let username = totpData.username {
            content.subtitle = username
        }
        // swiftlint:disable:next line_length
        content.body = "\"\(totpData.code)\" is copied to clipboard. Expiring in \(totpData.timerData.remaining) seconds"
        
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil) // Deliver immediately
        // There seems to be a 5 second limit to autofill extension.
        // if the delay goes above it stops working and doesn't remove the notification
        let delay = min(totpData.timerData.remaining, 5)
        notificationService.addWithTimer(for: request, and: Double(delay))
    }
}
    
// MARK: - Views
private extension CredentialProviderCoordinator {
    func showView(_ view: some View) {
        if let lastChildViewController {
            lastChildViewController.willMove(toParent: nil)
            lastChildViewController.view.removeFromSuperview()
            lastChildViewController.removeFromParent()
        }

        let viewController = UIHostingController(rootView: view)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        rootViewController.view.addSubview(viewController.view)
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor)
        ])
        rootViewController.addChild(viewController)
        viewController.didMove(toParent: rootViewController)
        lastChildViewController = viewController
    }

    func showCredentialsView(userData: UserData,
                             symmetricKey: SymmetricKey,
                             serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        guard let shareRepository,
              let shareEventIDRepository,
              let itemRepository,
              let upgradeChecker,
              let favIconRepository,
              let shareKeyRepository,
              let remoteSyncEventsDatasource else { return }
        let viewModel = CredentialsViewModel(userId: userData.user.ID,
                                             shareRepository: shareRepository,
                                             shareEventIDRepository: shareEventIDRepository,
                                             itemRepository: itemRepository,
                                             upgradeChecker: upgradeChecker,
                                             shareKeyRepository: shareKeyRepository,
                                             remoteSyncEventsDatasource: remoteSyncEventsDatasource,
                                             favIconRepository: favIconRepository,
                                             symmetricKey: symmetricKey,
                                             serviceIdentifiers: serviceIdentifiers,
                                             logManager: logManager,
                                             preferences: preferences)
        viewModel.delegate = self
        credentialsViewModel = viewModel
        showView(CredentialsView(viewModel: viewModel, preferences: preferences))
    }

    func showNotLoggedInView() {
        let view = NotLoggedInView(preferences: preferences) { [unowned self] in
            self.cancel(errorCode: .userCanceled)
        }
        showView(view)
    }

    // swiftlint:disable:next function_parameter_count
    func showCreateLoginView(shareId: String,
                             itemRepository: ItemRepositoryProtocol,
                             aliasRepository: AliasRepositoryProtocol,
                             upgradeChecker: UpgradeCheckerProtocol,
                             featureFlagsRepository: FeatureFlagsRepositoryProtocol,
                             vaults: [Vault],
                             url: URL?) {
        do {
            let creationType = ItemCreationType.login(title: url?.host,
                                                      url: url?.schemeAndHost,
                                                      autofill: true)
            let emailAddress = appData.userData?.addresses.first?.email ?? ""
            let viewModel = try CreateEditLoginViewModel(
                mode: .create(shareId: shareId,
                              type: creationType),
                itemRepository: itemRepository,
                aliasRepository: aliasRepository,
                upgradeChecker: upgradeChecker,
                featureFlagsRepository: featureFlagsRepository,
                vaults: vaults,
                preferences: preferences,
                logManager: logManager,
                emailAddress: emailAddress)
            viewModel.delegate = self
            viewModel.createEditLoginViewModelDelegate = self
            let view = CreateEditLoginView(viewModel: viewModel)
            present(view)
            currentCreateEditItemViewModel = viewModel
        } catch {
            logger.error(error)
            bannerManager.displayTopErrorMessage(error)
        }
    }

    func showGeneratePasswordView(delegate: GeneratePasswordViewModelDelegate) {
        if let wordProvider {
            let coordinator = GeneratePasswordCoordinator(generatePasswordViewModelDelegate: delegate,
                                                          mode: .createLogin,
                                                          wordProvider: wordProvider)
            coordinator.delegate = self
            coordinator.start()
            generatePasswordCoordinator = coordinator
        } else {
            Task { @MainActor in
                do {
                    let wordProvider = try await WordProvider()
                    self.wordProvider = wordProvider
                    showGeneratePasswordView(delegate: delegate)
                } catch {
                    logger.error(error)
                    bannerManager.displayTopErrorMessage(error)
                }
            }
        }
    }

    func showLoadingHud() {
        MBProgressHUD.showAdded(to: topMostViewController.view, animated: true)
    }

    func hideLoadingHud() {
        MBProgressHUD.hide(for: topMostViewController.view, animated: true)
    }

    func handleCreatedItem(_ itemContentType: ItemContentType) {
        topMostViewController.dismiss(animated: true) { [unowned self] in
            bannerManager.displayBottomSuccessMessage(itemContentType.creationMessage)
        }
    }

    func present<V: View>(_ view: V, animated: Bool = true, dismissible: Bool = false) {
        let viewController = UIHostingController(rootView: view)
        present(viewController)
    }

    func present(_ viewController: UIViewController, animated: Bool = true, dismissible: Bool = false) {
        viewController.isModalInPresentation = !dismissible
        viewController.overrideUserInterfaceStyle = preferences.theme.userInterfaceStyle
        topMostViewController.present(viewController, animated: animated)
    }

    func alert(error: Error) {
        let alert = UIAlertController(title: "Error occured",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [unowned self] _ in
            self.cancel(errorCode: .failed)
        }
        alert.addAction(cancelAction)
        rootViewController.present(alert, animated: true)
    }

    func startUpgradeFlow() {
        let alert = UIAlertController(title: "Upgrade",
                                      message: "Please open Proton Pass app to upgrade",
                                      preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        rootViewController.dismiss(animated: true) { [unowned self] in
            self.rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - GeneratePasswordCoordinatorDelegate
extension CredentialProviderCoordinator: GeneratePasswordCoordinatorDelegate {
    func generatePasswordCoordinatorWantsToPresent(viewController: UIViewController) {
        present(viewController)
    }
}

// MARK: - CredentialsViewModelDelegate
extension CredentialProviderCoordinator: CredentialsViewModelDelegate {
    func credentialsViewModelWantsToShowLoadingHud() {
        showLoadingHud()
    }

    func credentialsViewModelWantsToHideLoadingHud() {
        hideLoadingHud()
    }

    func credentialsViewModelWantsToCancel() {
        cancel(errorCode: .userCanceled)
    }

    func credentialsViewModelWantsToPresentSortTypeList(selectedSortType: SortType,
                                                        delegate: SortTypeListViewModelDelegate) {
        let viewModel = SortTypeListViewModel(sortType: selectedSortType)
        viewModel.delegate = delegate
        let view = SortTypeListView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * SortType.allCases.count + 60
        viewController.setDetentType(.custom(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }

    func credentialsViewModelWantsToCreateLoginItem(shareId: String, url: URL?) {
        guard let itemRepository,
              let aliasRepository,
              let shareRepository,
              let upgradeChecker,
              let featureFlagsRepository,
        let symmetricKey else { return }
        if let vaultListUiModels {
            showCreateLoginView(shareId: shareId,
                                itemRepository: itemRepository,
                                aliasRepository: aliasRepository,
                                upgradeChecker: upgradeChecker,
                                featureFlagsRepository: featureFlagsRepository,
                                vaults: vaultListUiModels.map { $0.vault },
                                url: url)
        } else {
            Task { @MainActor in
                do {
                    showLoadingHud()
                    let items = try await itemRepository.getAllItems()
                    let vaults = try await shareRepository.getVaults()

                    self.aliasCount = items.filter { $0.item.aliasEmail != nil }.count

                    self.vaultListUiModels = vaults.map { vault in
                        let activeItems =
                        items.filter { $0.item.itemState == .active && $0.shareId == vault.shareId }
                        return .init(vault: vault, itemCount: activeItems.count)
                    }

                    self.vaultCount = vaults.count

                    self.totpCount = try items
                        .filter { $0.isLogInItem }
                        .map { try $0.toItemUiModel(symmetricKey) }
                        .filter { $0.hasTotpUri }
                        .count

                    hideLoadingHud()
                    credentialsViewModelWantsToCreateLoginItem(shareId: shareId, url: url)
                } catch {
                    logger.error(error)
                    hideLoadingHud()
                    bannerManager.displayTopErrorMessage(error)
                }
            }
        }
    }

    func credentialsViewModelWantsToUpgrade() {
        startUpgradeFlow()
    }

    func credentialsViewModelDidSelect(credential: ASPasswordCredential,
                                       itemContent: ItemContent,
                                       serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        guard let itemRepository, let upgradeChecker else { return }
        complete(quickTypeBar: false,
                 credential: credential,
                 itemContent: itemContent,
                 itemRepository: itemRepository,
                 upgradeChecker: upgradeChecker,
                 serviceIdentifiers: serviceIdentifiers)
    }

    func credentialsViewModelDidFail(_ error: Error) {
        handle(error: error)
    }
}

// MARK: - CreateEditItemViewModelDelegate
extension CredentialProviderCoordinator: CreateEditItemViewModelDelegate {
    func createEditItemViewModelWantsToShowLoadingHud() {
        showLoadingHud()
    }

    func createEditItemViewModelWantsToHideLoadingHud() {
        hideLoadingHud()
    }

    func createEditItemViewModelWantsToChangeVault(selectedVault: Vault,
                                                   delegate: VaultSelectorViewModelDelegate) {
        guard let vaultListUiModels, let upgradeChecker else { return }
        let viewModel = VaultSelectorViewModel(allVaults: vaultListUiModels,
                                               selectedVault: selectedVault,
                                               upgradeChecker: upgradeChecker,
                                               logManager: logManager)
        viewModel.delegate = delegate
        let view = VaultSelectorView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = 66 * vaultListUiModels.count + 180 // Space for upsell banner
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }

    func createEditItemViewModelWantsToAddCustomField(delegate: CustomFieldAdditionDelegate) {
        let coordinator = CustomFieldAdditionCoordinator(rootViewController: rootViewController,
                                                         preferences: preferences,
                                                         delegate: delegate)
        coordinator.start()
    }

    func createEditItemViewModelWantsToEditCustomFieldTitle(_ uiModel: CustomFieldUiModel,
                                                            delegate: CustomFieldEditionDelegate) {
        let coordinator = CustomFieldEditionCoordinator(rootViewController: rootViewController,
                                                        delegate: delegate,
                                                        uiModel: uiModel)
        coordinator.start()
    }

    func createEditItemViewModelWantsToUpgrade() {
        startUpgradeFlow()
    }

    func createEditItemViewModelDidCreateItem(_ item: SymmetricallyEncryptedItem,
                                              type: ItemContentType) {
        switch type {
        case .login:
            credentialsViewModel?.select(item: item)
        default:
            handleCreatedItem(type)
        }
        addNewEvent(type: .create(type))
    }

    // Not applicable
    func createEditItemViewModelDidUpdateItem(_ type: ItemContentType) {}

    // Not applicable
    func createEditItemViewModelDidTrashItem(_ item: ItemIdentifiable, type: ItemContentType) {}

    func createEditItemViewModelDidEncounter(error: Error) {
        bannerManager.displayTopErrorMessage(error.localizedDescription)
    }
}

// MARK: - CreateEditLoginViewModelDelegate
extension CredentialProviderCoordinator: CreateEditLoginViewModelDelegate {
    func createEditLoginViewModelWantsToGenerateAlias(options: AliasOptions,
                                                      creationInfo: AliasCreationLiteInfo,
                                                      delegate: AliasCreationLiteInfoDelegate) {
        let viewModel = CreateAliasLiteViewModel(options: options, creationInfo: creationInfo)
        viewModel.aliasCreationDelegate = delegate
        viewModel.delegate = self
        let view = CreateAliasLiteView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        viewController.sheetPresentationController?.detents = [.medium()]
        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }

    func createEditLoginViewModelWantsToGeneratePassword(_ delegate: GeneratePasswordViewModelDelegate) {
        showGeneratePasswordView(delegate: delegate)
    }

    // Not applicable
    func createEditLoginViewModelWantsToOpenSettings() {}

    func createEditLoginViewModelWantsToUpgrade() {
        startUpgradeFlow()
    }
}

// MARK: - CreateAliasLiteViewModelDelegate
extension CredentialProviderCoordinator: CreateAliasLiteViewModelDelegate {
    func createAliasLiteViewModelWantsToSelectMailboxes(_ mailboxSelection: MailboxSelection) {
        guard let upgradeChecker else { return }
        let viewModel = MailboxSelectionViewModel(mailboxSelection: mailboxSelection,
                                                  upgradeChecker: upgradeChecker,
                                                  logManager: logManager,
                                                  mode: .createAliasLite,
                                                  titleMode: .create)
        viewModel.delegate = self
        let view = MailboxSelectionView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * mailboxSelection.mailboxes.count + 150
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController)
    }

    func createAliasLiteViewModelWantsToSelectSuffix(_ suffixSelection: SuffixSelection) {
        guard let upgradeChecker else { return }
        let viewModel = SuffixSelectionViewModel(suffixSelection: suffixSelection,
                                                 upgradeChecker: upgradeChecker,
                                                 logManager: logManager)
        viewModel.delegate = self
        let view = SuffixSelectionView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * suffixSelection.suffixes.count + 100
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController)
    }

    func createAliasLiteViewModelWantsToUpgrade() {
        startUpgradeFlow()
    }
}

// MARK: - MailboxSelectionViewModelDelegate
extension CredentialProviderCoordinator: MailboxSelectionViewModelDelegate {
    func mailboxSelectionViewModelWantsToUpgrade() {
        startUpgradeFlow()
    }

    func mailboxSelectionViewModelDidEncounter(error: Error) {
        bannerManager.displayTopErrorMessage(error)
    }
}

// MARK: - SuffixSelectionViewModelDelegate
extension CredentialProviderCoordinator: SuffixSelectionViewModelDelegate {
    func suffixSelectionViewModelWantsToUpgrade() {
        startUpgradeFlow()
    }

    func suffixSelectionViewModelDidEncounter(error: Error) {
        bannerManager.displayTopErrorMessage(error)
    }
}

// MARK: - ExtensionSettingsViewModelDelegate
extension CredentialProviderCoordinator: ExtensionSettingsViewModelDelegate {
    func extensionSettingsViewModelWantsToShowSpinner() {
        showLoadingHud()
    }

    func extensionSettingsViewModelWantsToHideSpinner() {
        hideLoadingHud()
    }

    func extensionSettingsViewModelWantsToDismiss() {
        context.completeExtensionConfigurationRequest()
    }

    func extensionSettingsViewModelWantsToLogOut() {
        appData.userData = nil
        context.completeExtensionConfigurationRequest()
    }

    func extensionSettingsViewModelDidEncounter(error: Error) {
        bannerManager.displayTopErrorMessage(error)
    }
}

// MARK: - LimitationCounterProtocol
extension CredentialProviderCoordinator: LimitationCounterProtocol {
    public func getAliasCount() -> Int {
        guard let aliasCount else { return 0 }
        return aliasCount
    }

    public func getVaultCount() -> Int {
        guard let vaultCount else { return 0 }
        return vaultCount
    }

    public func getTOTPCount() -> Int {
        guard let totpCount else { return 0 }
        return totpCount
    }
}
