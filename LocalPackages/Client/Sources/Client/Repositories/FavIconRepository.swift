//
// FavIconRepository.swift
// Proton Pass - Created on 14/04/2023.
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

import Core
import CryptoKit
import Entities
import Foundation
import ProtonCoreServices

public struct FavIcon: Hashable, Sendable {
    public let domain: String
    public let data: Data
    public let isFromCache: Bool
}

public protocol FavIconSettings: Sendable {
    var shouldDisplayFavIcons: Bool { get }
}

/// Take care of fetching and caching behind the scenes
public protocol FavIconRepositoryProtocol: Sendable {
    var settings: any FavIconSettings { get }

    /// Always return `nil` if fav icons are disabled in `Preferences`
    /// Check if the icon is cached on disk and decryptable. Otherwise go fetch a new icon.
    func getIcon(for domain: String) async throws -> FavIcon?

    /// Always return `nil` if fav icons are disabled in `Preferences`
    /// Only get icon from disk. Do not go fetch if icon is not cached.
    func getCachedIcon(for domain: String) async -> FavIcon?

    /// For debugging purposes only
    func getAllCachedIcons() async throws -> [FavIcon]

    /// Remove cached icons from disk
    func emptyCache() async throws
}

public actor FavIconRepository: FavIconRepositoryProtocol, DeinitPrintable {
    deinit { print(deinitMessage) }

    private let datasource: any RemoteFavIconDatasourceProtocol
    /// URL to the folder that contains cached fav icons
    private let containerUrl: URL
    private let cacheExpirationDays: Int
    public let settings: any FavIconSettings
    private let symmetricKeyProvider: any SymmetricKeyProvider
    private var activeTasks = [String: Task<FavIcon?, any Error>]()

    public init(datasource: any RemoteFavIconDatasourceProtocol,
                containerUrl: URL,
                settings: any FavIconSettings,
                symmetricKeyProvider: any SymmetricKeyProvider,
                cacheExpirationDays: Int = 14) {
        self.datasource = datasource
        self.containerUrl = containerUrl
        self.cacheExpirationDays = cacheExpirationDays
        self.settings = settings
        self.symmetricKeyProvider = symmetricKeyProvider
    }
}

public extension FavIconRepository {
    /// Fetches the favicon for the specified domain.
    /// - If the icon is already being fetched, it waits for the existing task to complete.
    /// - If the icon is cached and not obsolete, it returns the cached version.
    /// - Otherwise, it fetches the icon from the remote source and caches it.
    /// Parameters:
    ///   - domain: The domain for which to fetch the favicon.
    /// Returns: The fetched `FavIcon` object, or `nil` if the operation fails or is cancelled.
    func getIcon(for domain: String) async throws -> FavIcon? {
        guard settings.shouldDisplayFavIcons, !domain.isEmpty else { return nil }

        if let existingTask = activeTasks[domain] {
            if checkAndHandleCancellation(for: domain) { return nil }
            return try await existingTask.value
        }

        if checkAndHandleCancellation(for: domain) { return nil }
        let task = Task { [weak self] in
            // swiftlint:disable:next discouraged_optional_self
            try await self?.fetchAndCacheIcon(for: domain)
        }
        addActiveTask(task, for: domain)
        if checkAndHandleCancellation(for: domain) { return nil }
        return try await task.value
    }

    func getCachedIcon(for domain: String) -> FavIcon? {
        guard settings.shouldDisplayFavIcons else { return nil }
        let domain = URL(string: domain)?.host ?? domain
        let hashedDomain = domain.sha256
        let dataUrl = containerUrl.appendingPathComponent("\(hashedDomain).data",
                                                          conformingTo: .data)
        if let data = try? getDataOrRemoveIfObsolete(url: dataUrl) {
            return try? FavIcon(domain: domain,
                                data: getSymmetricKey().decrypt(data),
                                isFromCache: true)
        }
        return nil
    }

    func getAllCachedIcons() async throws -> [FavIcon] {
        let urls = try FileManager.default.contentsOfDirectory(at: containerUrl,
                                                               includingPropertiesForKeys: nil)

        let getDecryptedData: (URL) async throws -> Data? = { [weak self] url in
            guard let self else { return nil }
            let encryptedData = try Data(contentsOf: url)
            if encryptedData.isEmpty {
                return .init()
            } else {
                return try? await getSymmetricKey().decrypt(encryptedData)
            }
        }

        var icons = [FavIcon]()
        for url in urls where url.pathExtension == "data" {
            let hashedRootDomain = url.deletingPathExtension().lastPathComponent
            let domainUrl = containerUrl.appendingPathComponent("\(hashedRootDomain).domain",
                                                                conformingTo: .data)

            if let domainData = try await getDecryptedData(domainUrl),
               let decryptedRootDomain = String(data: domainData, encoding: .utf8),
               let decryptedImageData = try await getDecryptedData(url) {
                icons.append(.init(domain: decryptedRootDomain,
                                   data: decryptedImageData,
                                   isFromCache: true))
            }
        }

        return icons.sorted(by: { $0.domain < $1.domain })
    }

    func emptyCache() throws {
        guard FileManager.default.fileExists(atPath: containerUrl.path) else { return }
        let urls = try FileManager.default.contentsOfDirectory(at: containerUrl,
                                                               includingPropertiesForKeys: nil)
        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Utils

private extension FavIconRepository {
    func fetchAndCacheIcon(for domain: String) async throws -> FavIcon? {
        do {
            let symmetricKey = try getSymmetricKey()

            let domain = URL(string: domain)?.host ?? domain

            let hashedDomain = domain.sha256
            let dataUrl = containerUrl.appendingPathComponent("\(hashedDomain).data",
                                                              conformingTo: .data)
            if let encryptedData = try getDataOrRemoveIfObsolete(url: dataUrl),
               let decryptedData = try? symmetricKey.decrypt(encryptedData) {
                activeTasks[domain] = nil
                return FavIcon(domain: domain, data: decryptedData, isFromCache: true)
            }

            if checkAndHandleCancellation(for: domain) { return nil }

            // Fav icon is not cached (or cached but is obsolete/deleted/not decryptable), fetch from remote
            let result = try await datasource.fetchFavIcon(for: domain)

            let dataToWrite: Data = switch result {
            case let .positive(data):
                data
            case .negative:
                .init()
            }

            // Create 2 files: 1 contains the actual data & 1 contains the encrypted root domain
            try FileUtils.createOrOverwrite(data: symmetricKey.encrypt(dataToWrite),
                                            fileName: "\(hashedDomain).data",
                                            containerUrl: containerUrl)
            guard let domainData = domain.data(using: .utf8) else {
                throw PassError.crypto(.failedToEncode(domain))
            }
            try FileUtils.createOrOverwrite(data: symmetricKey.encrypt(domainData),
                                            fileName: "\(hashedDomain).domain",
                                            containerUrl: containerUrl)
            return FavIcon(domain: domain, data: dataToWrite, isFromCache: false)
        } catch {
            activeTasks[domain] = nil
            throw error
        }
    }

    func getSymmetricKey() throws -> SymmetricKey {
        try symmetricKeyProvider.getSymmetricKey()
    }

    func getDataOrRemoveIfObsolete(url: URL) throws -> Data? {
        let isObsolete = FileUtils.isObsolete(url: url,
                                              currentDate: .now,
                                              thresholdInDays: cacheExpirationDays)
        return try FileUtils.getDataRemovingIfObsolete(url: url, isObsolete: isObsolete)
    }
}

// MARK: - Task Management

private extension FavIconRepository {
    func addActiveTask(_ task: Task<FavIcon?, any Error>, for domain: String) {
        activeTasks[domain] = task
    }

    func cancelAndRemoveTask(for domain: String) {
        activeTasks[domain]?.cancel()
        activeTasks[domain] = nil
    }

    func checkAndHandleCancellation(for domain: String) -> Bool {
        if Task.isCancelled {
            cancelAndRemoveTask(for: domain)
            return true
        }
        return false
    }
}
