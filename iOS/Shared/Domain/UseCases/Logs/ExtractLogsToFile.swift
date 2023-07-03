//
//
// ExtractLogsToFile.swift
// Proton Pass - Created on 29/06/2023.
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
//

import Core
import Foundation

/**
 The ExtractLogsToFileUseCase protocol defines the contract for a use case that handles extracting log entries to a file.
 It inherits from the Sendable protocol, allowing the use case to be executed asynchronously.
 */
// sourcery: AutoMockable
protocol ExtractLogsToFileUseCase: Sendable {
    /**
     Executes the use case to extract the specified log entries to a file with the provided file name.

     - Parameters:
       - entries: An optional array of `LogEntry` objects representing the log entries to be extracted. If `nil`, no extraction will occur.
       - fileName: The name of the file to which the log entries will be written.

     - Returns: An optional `URL` pointing to the location of the extracted log file if the extraction was successful, otherwise `nil`.

     - Throws: An error if an issue occurs during the log extraction or file writing process.
     */
    func execute(for entries: [LogEntry]?, in fileName: String) async throws -> URL?
}

extension ExtractLogsToFileUseCase {
    /**
     Convenience method that allows the use case to be invoked as a function, simplifying its usage.

     - Parameters:
       - entries: An optional array of `LogEntry` objects representing the log entries to be extracted. If `nil`, no extraction will occur.
       - fileName: The name of the file to which the log entries will be written.

     - Returns: An optional `URL` pointing to the location of the extracted log file if the extraction was successful, otherwise `nil`.

     - Throws: An error if an issue occurs during the log extraction or file writing process.
     */
    func callAsFunction(for entries: [LogEntry]?, in fileName: String) async throws -> URL? {
        try await execute(for: entries, in: fileName)
    }
}

/**
 The ExtractLogsToFile class is an implementation of the `ExtractLogsToFileUseCase protocol. It provides functionality for extracting log entries to a file.
 */
final class ExtractLogsToFile: ExtractLogsToFileUseCase {
    private let logFormatter: LogFormatterProtocol

    init(logFormatter: LogFormatterProtocol) {
        self.logFormatter = logFormatter
    }

    /**
     Executes the use case to extract the specified log entries to a file with the provided file name.

     - Parameters:
       - entries: An optional array of `LogEntry` objects representing the log entries to be extracted. If `nil`, no extraction will occur.
       - fileName: The name of the file to which the log entries will be written.

     - Returns: An optional `URL` pointing to the location of the extracted log file if the extraction was successful, otherwise `nil`.

     - Throws: An error if an issue occurs during the log extraction or file writing process.
     */
    func execute(for entries: [LogEntry]?, in fileName: String) async throws -> URL? {
        guard let entries else {
            return nil
        }

        let file = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        let log = await logFormatter.format(entries: entries)
        try log.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
