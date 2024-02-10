//
// LogManager.swift
// Proton Pass - Created on 04/01/2023.
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

// sourcery: AutoMockable
public protocol LogManagerProtocol: Actor {
    var shouldLog: Bool { get }

    func log(entry: LogEntry)
    func getLogEntries() async throws -> [LogEntry]
    func removeAllLogs()
    func saveAllLogs()
    func toggleLogging(shouldLog: Bool)
}

public struct LogManagerConfig: Sendable {
    let maxLogLines: Int
    let dumpThreshold: Int
    let timerInterval: Double

    public init(maxLogLines: Int, dumpThreshold: Int = 300, timerInterval: Double = 30) {
        self.maxLogLines = maxLogLines
        self.dumpThreshold = dumpThreshold
        self.timerInterval = timerInterval
    }

    public static var `default`: LogManagerConfig {
        LogManagerConfig(maxLogLines: 5_000, dumpThreshold: 300, timerInterval: 30)
    }
}

public actor LogManager: LogManagerProtocol, Sendable {
    private let url: URL
    private var fileExists = false
    private var currentSavedlogs = [String]()
    private var currentMemoryLogs = [LogEntry]()
    private let config: LogManagerConfig
    private var timer: Timer?

    public private(set) var shouldLog = true

    private var numberOfLogAfterMerge: Int {
        currentSavedlogs.count + currentMemoryLogs.count
    }

    private var numberOfLogsToRemove: Int {
        numberOfLogAfterMerge - config.maxLogLines
    }

    /// Manage (read/write) the log file on disk
    /// - Parameters:
    ///    - url: The URL of the folder that contains the log file
    ///    - fileName: The name of the log file. E.g "proton.log"
    ///    - config: Configurations
    public init(url: URL, fileName: String, config: LogManagerConfig = .default) {
        self.url = url.appendingPathComponent(fileName, isDirectory: false)
        self.config = config
        fileExists = FileManager.default.fileExists(atPath: self.url.path)
        if let logContents = try? String(contentsOf: url, encoding: .utf8) {
            currentSavedlogs = logContents.components(separatedBy: .newlines)
        }
        Task { [weak self] in
            guard let self else { return }
            await setUp()
        }
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Public APIs

public extension LogManager {
    func log(entry: LogEntry) {
        guard shouldLog else {
            return
        }
        currentMemoryLogs.append(entry)
        guard currentMemoryLogs.count >= config.dumpThreshold else {
            return
        }
        saveAllLogs()
    }

    func getLogEntries() async throws -> [LogEntry] {
        guard fileExists else { return [] }
        let logContents = try String(contentsOf: url, encoding: .utf8)
        let lines = logContents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let entries = lines.compactMap(\.toLogEntry)
        return entries
    }

    func removeAllLogs() {
        guard fileExists else {
            return
        }
        do {
            try FileManager.default.removeItem(atPath: url.path)
            fileExists = false
            currentSavedlogs.removeAll()
            currentMemoryLogs.removeAll()
        } catch {
            print("Failed to remove log file: \(error.localizedDescription)")
        }
    }

    func saveAllLogs() {
        guard shouldLog else {
            return
        }
        do {
            try createLogFileIfNotExist()
            pruneLogs()
            mergeAndClear()
            try savedOnFile()
        } catch {
            print("Failed to log: \(error.localizedDescription)")
        }
    }

    func toggleLogging(shouldLog: Bool) {
        self.shouldLog = shouldLog
    }
}

// MARK: - Private APIs

private extension LogManager {
    func createLogFileIfNotExist() throws {
        guard !fileExists else {
            return
        }
        do {
            try Data().write(to: url)
            fileExists = true
        } catch {
            throw error
        }
    }

    func pruneLogs() {
        if numberOfLogAfterMerge > config.maxLogLines {
            currentSavedlogs.removeFirst(numberOfLogsToRemove)
        }
    }

    func mergeAndClear() {
        currentSavedlogs.append(contentsOf: currentMemoryLogs.compactMap(\.toString))
        currentMemoryLogs.removeAll()
    }

    func savedOnFile() throws {
        let updatedLogs = currentSavedlogs.joined(separator: "\n")
        try updatedLogs.data(using: .utf8)?.write(to: url)
    }
}

// MARK: - Utils

private extension LogManager {
    func setUp() {
        timer = Timer.scheduledTimer(withTimeInterval: config.timerInterval,
                                     repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self,
                      await currentMemoryLogs.count > self.config.dumpThreshold,
                      await shouldLog else { return }
                await saveAllLogs()
            }
        }
    }
}

// MARK: Utils Extensions

private extension LogEntry {
    var toString: String? {
        guard let jsonData = try? JSONEncoder().encode(self),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
}

private extension String {
    var toLogEntry: LogEntry? {
        guard let data = data(using: .utf8),
              let entry = try? JSONDecoder().decode(LogEntry.self, from: data) else {
            return nil
        }

        return entry
    }
}
