//
//  SettingsTests.swift
//  Proton Pass - Created on 12/23/22.
// 
// Copyright (c) 2023. Proton Technologies AG
//
// This file is part of Proton Pass.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import fusion
import ProtonCorePaymentsUI
import ProtonCoreQuarkCommands
import ProtonCoreTestingToolkitUnitTestsCore
import ProtonCoreTestingToolkitUITestsLogin
import XCTest

class SettingsTests: LoginBaseTestCase {
    let welcomeRobot = WelcomeRobot()
    let homeRobot = HomeRobot()

    func testItemListDisplayed() throws {
        let user = User(name: randomName, password: randomPassword)
        let quarkUser = try quarkCommands.userCreate(user: user)
        try quarkCommands.enableSubscription(id: quarkUser!.decryptedUserId, plan: "pass2023")

        welcomeRobot.logIn()
            .fillUsername(username: user.name)
            .fillpassword(password: user.password)
            .signIn(robot: AutoFillRobot.self)
            .notNowTap(robot: FaceIDRobot.self)
            .noThanks(robot: GetStartedRobot.self)
            .getStartedTap(robot: HomeRobot.self)
            .tapProfile()
            .verify.itemListContainsAllElements(login: "0", alias: "0", creditCard: "0", note: "0")
    }
}
