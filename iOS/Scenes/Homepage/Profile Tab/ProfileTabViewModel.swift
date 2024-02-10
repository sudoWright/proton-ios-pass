//
// ProfileTabViewModel.swift
// Proton Pass - Created on 07/03/2023.
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
import Combine
import Core
import Entities
import Factory
import ProtonCoreServices
import SwiftUI

@MainActor
protocol ProfileTabViewModelDelegate: AnyObject {
    func profileTabViewModelWantsToShowAccountMenu()
    func profileTabViewModelWantsToShowSettingsMenu()
    func profileTabViewModelWantsToShowFeedback()
    func profileTabViewModelWantsToQaFeatures()
}

@MainActor
final class ProfileTabViewModel: ObservableObject, DeinitPrintable {
    deinit { print(deinitMessage) }

    private let credentialManager = resolve(\SharedServiceContainer.credentialManager)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let preferences = resolve(\SharedToolingContainer.preferences)
    private let accessRepository = resolve(\SharedRepositoryContainer.accessRepository)
    private let userSettingsRepository = resolve(\SharedRepositoryContainer.userSettingsRepository)
    private let notificationService = resolve(\SharedServiceContainer.notificationService)
    private let securitySettingsCoordinator: SecuritySettingsCoordinator
    private let userDataProvider = resolve(\SharedDataContainer.userDataProvider)

    private let policy = resolve(\SharedToolingContainer.localAuthenticationEnablingPolicy)
    private let checkBiometryType = resolve(\SharedUseCasesContainer.checkBiometryType)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)

    // Use cases
    private let indexAllLoginItems = resolve(\SharedUseCasesContainer.indexAllLoginItems)
    private let unindexAllLoginItems = resolve(\SharedUseCasesContainer.unindexAllLoginItems)
    private let openAutoFillSettings = resolve(\UseCasesContainer.openAutoFillSettings)
    private let toggleSentinel = resolve(\SharedUseCasesContainer.toggleSentinel)
    private let getFeatureFlagStatus = resolve(\SharedUseCasesContainer.getFeatureFlagStatus)

    @Published private(set) var localAuthenticationMethod: LocalAuthenticationMethodUiModel = .none
    @Published private(set) var appLockTime: AppLockTime = .twoMinutes
    @Published var fallbackToPasscode = true {
        didSet {
            preferences.fallbackToPasscode = fallbackToPasscode
        }
    }

    /// Whether user has picked Proton Pass as AutoFill provider in Settings
    @Published private(set) var autoFillEnabled: Bool
    @Published var quickTypeBar: Bool { didSet { populateOrRemoveCredentials() } }
    @Published var automaticallyCopyTotpCode: Bool {
        didSet {
            if automaticallyCopyTotpCode {
                notificationService.requestNotificationPermission()
            }
            preferences.automaticallyCopyTotpCode = automaticallyCopyTotpCode
        }
    }

    @Published private(set) var loading = false
    @Published private(set) var plan: Plan?
    @Published private(set) var isSentinelEligible = false
    @Published private(set) var isSentinelActive = false
    @Published private(set) var updatingSentinel = false

    private var cancellables = Set<AnyCancellable>()
    weak var delegate: ProfileTabViewModelDelegate?

    var sentinelEnabled: Bool {
        getFeatureFlagStatus(with: FeatureFlagType.passSentinelV1)
    }

    init(childCoordinatorDelegate: ChildCoordinatorDelegate) {
        let securitySettingsCoordinator = SecuritySettingsCoordinator()
        securitySettingsCoordinator.delegate = childCoordinatorDelegate
        self.securitySettingsCoordinator = securitySettingsCoordinator

        autoFillEnabled = false
        quickTypeBar = preferences.quickTypeBar
        automaticallyCopyTotpCode = preferences.automaticallyCopyTotpCode

        refresh()

        setUp()
    }
}

// MARK: - Public APIs

extension ProfileTabViewModel {
    func upgrade() {
        router.present(for: .upgradeFlow)
    }

    @MainActor
    func refreshPlan() async {
        do {
            // First get local plan to optimistically display it
            // and then try to refresh the plan to have it updated
            plan = try await accessRepository.getPlan()
            plan = try await accessRepository.refreshAccess().plan
        } catch {
            logger.error(error)
            router.display(element: .displayErrorBanner(error))
        }
    }

    @MainActor
    func checkSentinel() async {
        guard sentinelEnabled, let userId = try? userDataProvider.getUserId() else {
            return
        }
        let settings = await userSettingsRepository.getSettings(for: userId)
        isSentinelEligible = settings.highSecurity.eligible
        isSentinelActive = settings.highSecurity.value
    }

    func toggleSentinelState() {
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                updatingSentinel = false
            }
            do {
                updatingSentinel = true
                let userId = try userDataProvider.getUserId()
                try await toggleSentinel(for: userId)
                await checkSentinel()
            } catch {
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func showSentinelInformation() {
        router.navigate(to: .urlPage(urlString: "https://proton.me/support/proton-sentinel"))
    }

    func editLocalAuthenticationMethod() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editMethod()
        }
    }

    func editAppLockTime() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editAppLockTime()
        }
    }

    func editPINCode() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editPINCode()
        }
    }

    func handleEnableAutoFillAction() {
        openAutoFillSettings()
    }

    func showAccountMenu() {
        delegate?.profileTabViewModelWantsToShowAccountMenu()
    }

    func showSettingsMenu() {
        delegate?.profileTabViewModelWantsToShowSettingsMenu()
    }

    func showPrivacyPolicy() {
        router.navigate(to: .urlPage(urlString: ProtonLink.privacyPolicy))
    }

    func showTermsOfService() {
        router.navigate(to: .urlPage(urlString: ProtonLink.termsOfService))
    }

    func showImportInstructions() {
        router.navigate(to: .urlPage(urlString: ProtonLink.howToImport))
    }

    func showImportExportFlow() {
        router.present(for: .importExport)
    }

    func showTutorial() {
        router.present(for: .tutorial)
    }

    func showFeedback() {
        delegate?.profileTabViewModelWantsToShowFeedback()
    }

    func qaFeatures() {
        delegate?.profileTabViewModelWantsToQaFeatures()
    }
}

// MARK: - Private APIs

private extension ProfileTabViewModel {
    func setUp() {
        Task { [weak self] in
            guard let self else {
                return
            }
            await checkSentinel()
        }

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                refresh()
            }
            .store(in: &cancellables)

        preferences.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                updateAutoFillAvalability()
                updateSecuritySettings()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        updateAutoFillAvalability()
        updateSecuritySettings()
    }

    func updateSecuritySettings() {
        switch preferences.localAuthenticationMethod {
        case .none:
            localAuthenticationMethod = .none
        case .biometric:
            do {
                let biometryType = try checkBiometryType(policy: policy)
                localAuthenticationMethod = .biometric(biometryType)
            } catch {
                // Fallback to `none`, not much we can do except displaying the error
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
                localAuthenticationMethod = .none
            }
        case .pin:
            localAuthenticationMethod = .pin
        }

        appLockTime = preferences.appLockTime

        if preferences.fallbackToPasscode != fallbackToPasscode {
            // Check before assigning because `fallbackToPasscode` has a `didSet` block
            // that updates preferences hence trigger an infinitely loop
            fallbackToPasscode = preferences.fallbackToPasscode
        }
    }

    func updateAutoFillAvalability() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            autoFillEnabled = await credentialManager.isAutoFillEnabled
        }
    }

    func populateOrRemoveCredentials() {
        // When not enabled, iOS already deleted the credential database.
        // Atempting to populate this database will throw an error anyway so early exit here
        guard autoFillEnabled else { return }

        guard quickTypeBar != preferences.quickTypeBar else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.loading = false }
            do {
                self.logger.trace("Updating credential database QuickTypeBar \(self.quickTypeBar)")
                self.loading = true
                if self.quickTypeBar {
                    try await self.indexAllLoginItems(ignorePreferences: true)
                } else {
                    try await self.unindexAllLoginItems()
                }
                self.preferences.quickTypeBar = self.quickTypeBar
            } catch {
                self.logger.error(error)
                self.quickTypeBar.toggle() // rollback to previous value
                self.router.display(element: .displayErrorBanner(error))
            }
        }
    }
}
