//
//  File.swift
//  
//
//  Created by Patrick Fischer on 27.04.22.
//

import Foundation
import CoreData


public class PersistentHistoryProcessor: NSObject {
    public typealias Config = (currentOriginator: PersistentHistoryOriginator, userDefaults: UserDefaults)
    private let config: Config
    private var context: NSManagedObjectContext?
    
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
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        persistentContainer.persistentStoreDescriptions = [storeDescription]
    }
    
    internal func setup(context: NSManagedObjectContext,
                        container: NSPersistentContainer,
                        notificationCenter: NotificationCenter) {
        self.context = context
        startObserving(container: container, notificationCenter: notificationCenter)
    }
    
    private func startObserving(container: NSPersistentContainer,
                                notificationCenter: NotificationCenter) {
        notificationCenter.addObserver(self, selector: #selector(process), name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
        
    }
    
    @objc private func process(_ notification: Notification) {
        context?.performAndWait {
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
