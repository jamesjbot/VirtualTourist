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
    private let sqlFilename : String = "jamesjongs.sqlite"
    
    // MARK: - Variables
    private var model: NSManagedObjectModel!
    private var mainStoreCoordinator: NSPersistentStoreCoordinator!
    private var modelURL: NSURL!
    private var dbURL: NSURL!
    //private var persistentContext: NSManagedObjectContext!
    //private var backgroundCentext : NSManagedObjectContext!
    var context: NSManagedObjectContext! //in Udacity code we call this context
    var backgroundContext : NSManagedObjectContext!
    
    
    // MARK: - Initializers
    init?(modelName: String) {
        super.init()
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = NSBundle.mainBundle().URLForResource(modelName, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        
        print("Model url found \(modelURL)")
        // Save the modelURL
        self.modelURL = modelURL
        
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        
        print("Managed Object model created")
        
        // Save the managedObjectModel
        self.model = mom
        
        // Create the persistent store coordinator
        mainStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)
        
        // Create Managed Ojbect Context running on the MainQueue
        context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        // Assign coordinator to context
        context.persistentStoreCoordinator = mainStoreCoordinator
        
        backgroundContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        backgroundContext.parentContext = context

        
        
        // Add an SQL lite store in the documents folder
        // Create the SQL Store in the background
        //dispatch_sync(dispatch_get_main_queue()){
        print("Dispatching jobs to grab file")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            // get the documents directory.
            let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
            // Save the url location of the document directory
            let docURL = urls[urls.endIndex-1]
            
            /* The directory the application uses to store the Core Data store file.
             This code uses a file named "DataModel.sqlite" in the application's documents directory.
             */
            
            // Name the SQL Lite file we are creating
            self.dbURL = docURL.URLByAppendingPathComponent(self.sqlFilename)
            

            // Migrate to new DataModel with photoalbum
            let options = [NSInferMappingModelAutomaticallyOption: true,
                           NSMigratePersistentStoresAutomaticallyOption: true]
            
            do {
                print("Trying to add persistent store")
                try self.mainStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: self.dbURL, options: options)
                print("Successfully added persistent Store")
                
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }

    }
}

extension CoreDataStack {
    func saveContext() throws{
        if context.hasChanges{
            do {
                try backgroundContext.save()
                try context.save()
                
            } catch {
                print("From coredatastack failed to saveContext")
            }

        }
    }
    
    func displayUnsavedElements() {
        print("deleted objects \(context.deletedObjects)")
        print("inserted objects \(context.insertedObjects)")
        print("updated objects \(context.updatedObjects)")
        print("deleted objects \(backgroundContext.deletedObjects)")
        print("inserted objects \(backgroundContext.insertedObjects)")
        print("updated objects \(backgroundContext.updatedObjects)")
    }
    
}



