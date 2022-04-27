import Foundation
import CoreData

public class LSCoreDataStack {
    
    private var persistentHistoryProcessor: PersistentHistoryProcessor?
    public let mainContext: NSManagedObjectContext
    public let backgroundContext: NSManagedObjectContext
    
    public let notificationCenter: NotificationCenter
    
    public let modelName: String
    
    public init(modelName: String,
                managedObjectModel: NSManagedObjectModel? = nil,
                notificationCenter: NotificationCenter = NotificationCenter.default,
                persistentHistoryProcessor: PersistentHistoryProcessor? = nil) throws {
        self.notificationCenter = notificationCenter
        self.modelName = modelName
        let persistentContainer: NSPersistentContainer
        
        self.persistentHistoryProcessor = persistentHistoryProcessor
        
        if let managedObjectModel = managedObjectModel {
            persistentContainer = NSPersistentContainer(
                name: modelName, managedObjectModel: managedObjectModel)
        } else {
            persistentContainer = NSPersistentContainer(name: modelName)
        }
        persistentHistoryProcessor?.addStoreDescriptions(for: persistentContainer)
        persistentContainer.loadPersistentStores { (_, error) in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        
        mainContext = persistentContainer.viewContext
        backgroundContext = persistentContainer.newBackgroundContext()
                
        setupContextMerging()
        persistentHistoryProcessor?.setup(mainContext: mainContext,
                                          backgroundContext: backgroundContext,
                                          container: persistentContainer,
                                          notificationCenter: notificationCenter)
    }
    
    private func setupContextMerging() {
        notificationCenter.addObserver(self,
                                       selector: #selector(handleBackgroundContextSaved(_:)),
                                       name: .NSManagedObjectContextDidSave,
                                       object: backgroundContext)
        
        notificationCenter.addObserver(self,
                                       selector: #selector(handleMainContextSaved(_:)),
                                       name: .NSManagedObjectContextDidSave,
                                       object: mainContext)
    }
    
    @objc private func handleBackgroundContextSaved(_ notification: Notification) {
        mainContext.perform { [unowned self] in
            self.mainContext.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    @objc private func handleMainContextSaved(_ notification: Notification) {
        backgroundContext.perform { [unowned self] in
            self.backgroundContext.mergeChanges(fromContextDidSave: notification)
        }
    }
}
