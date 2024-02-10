//
// ItemContentTests.swift
// Proton Pass - Created on 20/09/2022.
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

@testable import Client
import CryptoKit
import Entities
import XCTest

final class ItemContentTests: XCTestCase {
    func testEncryptAndDecrypt() throws {
        // Given
        let givenItemContent = ItemContentProtobuf(name: .random(),
                                                   note: .random(),
                                                   itemUuid: UUID().uuidString,
                                                   data: .random(),
                                                   customFields: [.init(title: .random(),
                                                                        type: .text,
                                                                        content: .random())])
        let givenSymmetricKey = SymmetricKey.random()

        // When
        let encryptedItemContent = try givenItemContent.encrypt(symmetricKey: givenSymmetricKey)

        // Then
        let itemContent = try ItemContentProtobuf(base64: encryptedItemContent,
                                                  symmetricKey: givenSymmetricKey)
        XCTAssertEqual(itemContent, givenItemContent)
    }
}
