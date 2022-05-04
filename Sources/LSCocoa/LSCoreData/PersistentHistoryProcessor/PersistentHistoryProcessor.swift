//
//  File.swift
//  
//
//  Created by Patrick Fischer on 27.04.22.
//

import Foundation
import CoreData


public class PersistentHistoryProcessor: NSObject {
    enum Error: Swift.Error {
        case identicalIdentifiers
        case historyTransactionConvertionFailed
    }
    public struct Config {
        fileprivate let currentOriginator: PersistentDataOriginator
        fileprivate let userDefaults: UserDefaults
        public init(currentOriginator: PersistentDataOriginator,
                    userDefaults: UserDefaults = .standard) {
            self.currentOriginator = currentOriginator
            self.userDefaults = userDefaults
        }
    }
    private let config: Config
    private var backgroundContext: NSManagedObjectContext?
    
    public init(config: Config) throws {
        let allTargets = config.currentOriginator.allOrignators
        let idenfifiers = Set(allTargets.map { $0.identifier })
        if idenfifiers.count != allTargets.count {
            throw Error.identicalIdentifiers
        }
        self.config = config
    }
    
    internal func addStoreDescriptions(for persistentContainer:  NSPersistentContainer) {
        if let storeURL = persistentContainer.persistentStoreDescriptions.last?.url {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            persistentContainer.persistentStoreDescriptions = [storeDescription]
        }
    }
    
    internal func setup(mainContext: NSManagedObjectContext,
                        backgroundContext: NSManagedObjectContext,
                        container: NSPersistentContainer,
                        notificationCenter: NotificationCenter) {
        mainContext.name = config.currentOriginator.identifier
        mainContext.transactionAuthor = config.currentOriginator.identifier
        backgroundContext.name = config.currentOriginator.identifier
        backgroundContext.transactionAuthor = config.currentOriginator.identifier
        self.backgroundContext = backgroundContext
        startObserving(container: container, notificationCenter: notificationCenter)
    }
    
    private func startObserving(container: NSPersistentContainer,
                                notificationCenter: NotificationCenter) {
        notificationCenter.addObserver(self, selector: #selector(process), name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
        
    }
    
    @objc private func process(_ notification: Notification) {
        backgroundContext?.performAndWait {
            do {
                try merge()
                try clean()
            } catch {
                print("PersistentHistoryProcessor: failed with error \(error)")
            }
        }
    }
    
    private func merge() throws {
        let fromDate = config.userDefaults.lastHistoryTransactionTimestamp(for: config.currentOriginator) ?? .distantPast
        let history = try fetch(fromDate: fromDate)
        
        guard !history.isEmpty else {
            print("PersistentHistoryProcessor: No history transactions found to merge for target \(config.currentOriginator)")
            return
        }
        
        print("PersistentHistoryProcessor: Merging \(history.count) persistent history transactions for target \(config.currentOriginator)")
        
        if let context = backgroundContext {
            history.merge(into: context)
        }

        
        guard let lastTimestamp = history.last?.timestamp else { return }
        config.userDefaults.updateLastHistoryTransactionTimestamp(for: config.currentOriginator, to: lastTimestamp)
    }
    
    /// Cleans up the persistent history by deleting the transactions that have been merged into each originator.
    private func clean() throws {
        guard let timestamp = config.userDefaults.lastCommonTransactionTimestamp(in: config.currentOriginator.allOrignators) else {
            print("PersistentHistoryProcessor: Cancelling deletions as there is no common transaction timestamp")
            return
        }

        let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: timestamp)
        print("PersistentHistoryProcessor: Deleting persistent history using common timestamp \(timestamp)")
        try backgroundContext?.execute(deleteHistoryRequest)

        config.currentOriginator.allOrignators.forEach { target in
            /// Reset the dates as we would otherwise end up in an infinite loop.
            config.userDefaults.updateLastHistoryTransactionTimestamp(for: target, to: nil)
        }
    }
    
    private func fetch(fromDate: Date) throws -> [NSPersistentHistoryTransaction] {
        let fetchRequest = createFetchRequest(fromDate: fromDate)
        guard let historyResult = try backgroundContext?.execute(fetchRequest) as? NSPersistentHistoryResult, let history = historyResult.result as? [NSPersistentHistoryTransaction] else {
            throw Error.historyTransactionConvertionFailed
        }
        return history
    }
    
    private func createFetchRequest(fromDate: Date) -> NSPersistentHistoryChangeRequest {
        let historyFetchRequest = NSPersistentHistoryChangeRequest
                    .fetchHistory(after: fromDate)

                if let fetchRequest = NSPersistentHistoryTransaction.fetchRequest {
                    var predicates: [NSPredicate] = []
                    if let transactionAuthor = backgroundContext?.transactionAuthor {
                        /// Only look at transactions created by other targets.
                        predicates.append(NSPredicate(format: "%K != %@",
                                                      #keyPath(NSPersistentHistoryTransaction.author),
                                                      transactionAuthor))
                    }
                    if let contextName = backgroundContext?.name {
                        /// Only look at transactions not from our current context.
                        predicates.append(NSPredicate(format: "%K != %@",
                                                      #keyPath(NSPersistentHistoryTransaction.contextName),
                                                      contextName))
                    }
                    fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: predicates)
                    historyFetchRequest.fetchRequest = fetchRequest
                }
                return historyFetchRequest
    }
}

fileprivate extension Collection where Element == NSPersistentHistoryTransaction {
    
    /// Merges the current collection of history transactions into the given managed object context.
    /// - Parameter context: The managed object context in which the history transactions should be merged.
    func merge(into context: NSManagedObjectContext) {
        forEach { transaction in
            guard let userInfo = transaction.objectIDNotification().userInfo else { return }
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [context])
        }
    }
}

fileprivate extension UserDefaults {
    
    func lastHistoryTransactionTimestamp(for originator: PersistentDataOriginator) -> Date? {
        let key = "lastHistoryTransactionTimeStamp-\(originator.identifier)"
        return object(forKey: key) as? Date
    }

    func updateLastHistoryTransactionTimestamp(for originator: PersistentDataOriginator, to newValue: Date?) {
        let key = "lastHistoryTransactionTimeStamp-\(originator.identifier)"
        set(newValue, forKey: key)
    }

    func lastCommonTransactionTimestamp(in originators: [PersistentDataOriginator]) -> Date? {
        let timestamp = originators
            .map { lastHistoryTransactionTimestamp(for: $0) ?? .distantPast }
            .min() ?? .distantPast
        return timestamp > .distantPast ? timestamp : nil
    }
}
