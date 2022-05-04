//
//  File.swift
//  
//
//  Created by Patrick Fischer on 27.04.22.
//

import Foundation
import CoreData


public class PersistentHistoryProcessor: NSObject {
    public struct Config {
        let currentOriginator: PersistentDataOriginator
        let userDefaults: UserDefaults
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
            throw NSError(domain: "PersistentHistoryMerger", code: 0, userInfo: [
                "Info":"Please make sure you use different identifiers for your targets",
                "identifiers": idenfifiers
            ])
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
                // print("Persistent History Tracking failed with error \(error)")
            }
        }
    }
    
    private func merge() throws {
        
    }
    
    private func clean() throws {
        
    }
}
