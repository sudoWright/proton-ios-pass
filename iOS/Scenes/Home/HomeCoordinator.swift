//
// HomeCoordinator.swift
// Proton Pass - Created on 02/07/2022.
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
import MBProgressHUD
import ProtonCore_Login
import ProtonCore_Services
import SideMenuSwift
import SwiftUI
import UIComponents
import UIKit

protocol HomeCoordinatorDelegate: AnyObject {
    func homeCoordinatorDidSignOut()
}

// swiftlint:disable:next todo
// TODO: Make width dynamic based on screen orientation
private let kMenuWidth = UIScreen.main.bounds.width * 4 / 5

final class HomeCoordinator {
    deinit {
        print("\(Self.self) is deallocated")
    }

    let userData: UserData
    let apiService: APIService
    weak var delegate: HomeCoordinatorDelegate?

    private(set) lazy var sideMenuController: SideMenuController = {
        let sideMenuController = SideMenuController(contentViewController: myVaultsRootViewController,
                                                    menuViewController: sidebarViewController)
        return sideMenuController
    }()

    private var topMostViewController: UIViewController {
        sideMenuController.presentedViewController ?? sideMenuController
    }

    private lazy var sidebarViewController: UIViewController = {
        let sidebarView = SidebarView(coordinator: self, width: kMenuWidth)
        return UIHostingController(rootView: sidebarView)
    }()

    // My vaults
    private lazy var myVaultsCoordinator: MyVaultsCoordinator = {
        let myVaultsCoordinator = MyVaultsCoordinator(apiService: apiService,
                                                      userData: userData)
        myVaultsCoordinator.delegate = self
        return myVaultsCoordinator
    }()

    private var myVaultsRootViewController: UIViewController { myVaultsCoordinator.router.toPresentable() }

    // Trash
    private lazy var trashCoordinator: TrashCoordinator = {
        let trashCoordinator = TrashCoordinator()
        trashCoordinator.delegate = self
        return trashCoordinator
    }()

    private var trashRootViewController: UIViewController { trashCoordinator.router.toPresentable() }

    init(userData: UserData, apiService: APIService) {
        self.userData = userData
        self.apiService = apiService
        self.setUpSideMenuPreferences()
    }

    private func setUpSideMenuPreferences() {
        SideMenuController.preferences.basic.menuWidth = kMenuWidth
        SideMenuController.preferences.basic.position = .sideBySide
        SideMenuController.preferences.basic.enablePanGesture = true
        SideMenuController.preferences.basic.enableRubberEffectWhenPanning = false
        SideMenuController.preferences.animation.shouldAddShadowWhenRevealing = true
        SideMenuController.preferences.animation.shadowColor = .black
        SideMenuController.preferences.animation.shadowAlpha = 0.52
        SideMenuController.preferences.animation.revealDuration = 0.25
        SideMenuController.preferences.animation.hideDuration = 0.25
    }
}

// MARK: - Sidebar
extension HomeCoordinator {
    func showSidebar() {
        sideMenuController.revealMenu()
    }

    func handleSidebarItem(_ sidebarItem: SidebarItem) {
        switch sidebarItem {
        case .myVaults:
            sideMenuController.setContentViewController(to: myVaultsRootViewController,
                                                        animated: true) { [unowned self] in
                self.sideMenuController.hideMenu()
            }
        case .settings:
            break
        case .trash:
            sideMenuController.setContentViewController(to: trashRootViewController,
                                                        animated: true) { [unowned self] in
                self.sideMenuController.hideMenu()
            }
        case .help:
            break
        case .signOut:
            requestSignOutConfirmation()
        }
    }

    func showUserSwitcher() {
        print(#function)
    }

    func alert(error: Error) {
        let alert = UIAlertController(title: "Error occured",
                                      message: error.messageForTheUser,
                                      preferredStyle: .alert)
        alert.addAction(.cancel)
        topMostViewController.present(alert, animated: true)
    }
}

// MARK: - Sign out
extension HomeCoordinator {
    private func requestSignOutConfirmation() {
        let alert = UIAlertController(title: "You will be signed out",
                                      message: "All associated data will be deleted. Please confirm.",
                                      preferredStyle: .alert)
        let signOutAction = UIAlertAction(title: "Yes, sign me out", style: .destructive) { [unowned self] _ in
            self.signOut()
        }
        alert.addAction(signOutAction)
        alert.addAction(.cancel)
        sideMenuController.present(alert, animated: true)
    }

    private func signOut() {
        delegate?.homeCoordinatorDidSignOut()
    }
}

// MARK: - MyVaultsCoordinatorDelegate
extension HomeCoordinator: MyVaultsCoordinatorDelegate {
    func myVautsCoordinatorWantsToShowSidebar() {
        showSidebar()
    }

    func myVautsCoordinatorWantsToShowLoadingHud() {
        MBProgressHUD.showAdded(to: topMostViewController.view, animated: true)
    }

    func myVautsCoordinatorWantsToHideLoadingHud() {
        MBProgressHUD.hide(for: topMostViewController.view, animated: true)
    }

    func myVautsCoordinatorWantsToAlertError(_ error: Error) {
        alert(error: error)
    }
}

// MARK: - TrashCoordinatorDelegate
extension HomeCoordinator: TrashCoordinatorDelegate {
    func trashCoordinatorWantsToShowSidebar() {
        showSidebar()
    }
}

extension HomeCoordinator {
    /// For preview purposes
    static var preview: HomeCoordinator {
        .init(userData: .preview, apiService: DummyApiService.preview)
    }
}
