//
//  CoreDataStack.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/4/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import CoreData

class CoreDataStack: NSObject {
    // MARK: - Constants
    fileprivate let sqlFilename : String = "com.jamesjongs.sqlite"
    
    // MARK: - Variables
    fileprivate var model: NSManagedObjectModel!
    fileprivate var mainStoreCoordinator: NSPersistentStoreCoordinator!
    fileprivate var modelURL: URL!
    fileprivate var dbURL: URL!
    internal var persistingContext: NSManagedObjectContext!
    internal var backgroundContext : NSManagedObjectContext!
    internal var mainContext: NSManagedObjectContext!
    
    
    // MARK: - Initializers
    init?(modelName: String) {
        super.init()
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        
        // Save the modelURL
        self.modelURL = modelURL
        
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        
        // Save the managedObjectModel
        self.model = mom
        
        // Create the persistent store coordinator
        mainStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)
        
        // Create the persisting context
        persistingContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        
        // Assign coordinator to persisting context
        persistingContext.persistentStoreCoordinator = mainStoreCoordinator
        
        // Create Managed Ojbect Context running on the MainQueue
        mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainContext.parent = persistingContext
        
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = mainContext

        
        
        // Add an SQL lite store in the documents folder
        // Create the SQL Store in the background
        //dispatch_sync(dispatch_get_main_queue()){
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async {
            // get the documents directory.
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            // Save the url location of the document directory
            let docURL = urls[urls.endIndex-1]
            
            /* The directory the application uses to store the Core Data store file.
             This code uses a file named "DataModel.sqlite" in the application's documents directory.
             */
            
            // Name the SQL Lite file we are creating
            self.dbURL = docURL.appendingPathComponent(self.sqlFilename)
            

            // Migrate to new DataModel with photoalbum
            let options = [NSInferMappingModelAutomaticallyOption: true,
                           NSMigratePersistentStoresAutomaticallyOption: true]
            
            do {
                try self.mainStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: self.dbURL, options: options)
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }

    }
}

extension CoreDataStack {
    internal func saveBackgroundContext() throws {
        if backgroundContext.hasChanges {
            backgroundContext.performAndWait {
                do {
                    try self.backgroundContext.save()
                } catch {
                    fatalError("Error saving background")
                }
            }
        }
    }
    
    internal func saveMainContext() throws{
        if mainContext.hasChanges{
            do {
                try mainContext.save()
            }
        }
    }
    
    internal func savePersistingContext() throws {
        if persistingContext.hasChanges{
            do {
                try persistingContext.save()
            } 
        }
    }
    
    internal func saveToFile() {
        // We call this synchronously, but it's a very fast
        // operation (it doesn't hit the disk). We need to know
        // when it ends so we can call the next save (on the persisting
        // context). The last save might take some time and is done
        // in a background queue
        
        backgroundContext.performAndWait(){
            do{
                try self.backgroundContext.save()
            } catch let error {
                fatalError("Error while saving background context:\n\(error)")
            }
            // Now we save the main
            self.mainContext.performAndWait(){
                do {
                    try self.saveMainContext()
                } catch let error {
                    fatalError("Error while saving mainContext:\n\(error)")
                }
                self.persistingContext.performAndWait(){
                    do{
                        try self.persistingContext.save()
                    } catch let error {
                        fatalError("Error while saving persisting context:\n\(error)")
                    }
                }
            }
        }
    }
}



