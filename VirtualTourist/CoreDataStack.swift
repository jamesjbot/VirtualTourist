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
    private var coordinator: NSPersistentStoreCoordinator!
    private var modelURL: NSURL!
    private var dbURL: NSURL!
    //private var persistentContext: NSManagedObjectContext!
    //private var backgroundCentext : NSManagedObjectContext!
    var context: NSManagedObjectContext! //in Udacity code we call this context
    
    // MARK: - Initializers
    init?(modelName: String) {
        super.init()
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = NSBundle.mainBundle().URLForResource(modelName, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        
        // Save the modelURL
        self.modelURL = modelURL
        
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        
        // Save the managedObjectModel
        self.model = mom
        
        // Create the persistent store coordinator
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)
        
        // Create Managed Ojbect Context
        context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        
        // Assign coordinator to context
        context.persistentStoreCoordinator = coordinator
        
        
        // Add an SQL lite store in the documents folder
        // Create the SQL Store in the background
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
            do {
                try self.coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: self.dbURL, options: nil)
                
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
    }
    
}



