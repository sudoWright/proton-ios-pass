//
// FileUtils.swift
// Proton Pass - Created on 16/04/2023.
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

import Foundation

public enum FileUtils {
    public static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    /// Create the file with given data, if the file already exists, overwrite with the given data.
    /// - Parameters:
    ///   - data: The data to be written to the file
    ///   - fileName: The name of the file
    ///   - containerUrl: URL of the folder which the file should belongs to
    ///
    /// - Returns:The `URL` of the file
    @discardableResult
    public static func createOrOverwrite(data: Data?,
                                         fileName: String,
                                         containerUrl: URL) throws -> URL {
        // Create the containing folder if not exist first
        if !FileManager.default.fileExists(atPath: containerUrl.path) {
            try FileManager.default.createDirectory(at: containerUrl,
                                                    withIntermediateDirectories: true)
        }

        let fileUrl = containerUrl.appendingPathComponent(fileName, conformingTo: .data)

        if FileManager.default.fileExists(atPath: fileUrl.path) {
            try data?.write(to: fileUrl)
        } else {
            FileManager.default.createFile(atPath: fileUrl.path, contents: data)
        }
        return fileUrl
    }

    /// Return `nil` if the file does not exist or is removed
    public static func getDataRemovingIfObsolete(url: URL, isObsolete: Bool) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        if isObsolete {
            // Removal might fail, we don't care
            // so we ignore the error by doing `try?` instead of `try`
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return try Data(contentsOf: url)
    }

    /// - Returns: `nil` if the file does not exist or failed to get file's attributes
    public static func getModificationDate(url: URL) throws -> Date? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date
    }

    /// - Returns: `nil` if the file does not exist or failed to get file's attributes
    public static func getCreationDate(url: URL) throws -> Date? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.creationDate] as? Date
    }

    /// Do not care if the file exist or not.
    /// Consider obsolete by default if the file does not exist or fail to get file's attributes
    public static func isObsolete(url: URL, currentDate: Date, thresholdInDays: Int) -> Bool {
        guard let modificationDate = try? getModificationDate(url: url) else { return true }
        let numberOfDays = Calendar.current.numberOfDaysBetween(modificationDate,
                                                                and: currentDate)
        return abs(numberOfDays) >= thresholdInDays
    }
}
