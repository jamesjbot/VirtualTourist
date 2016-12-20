//
//  Pin+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/25/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Pin {

    @NSManaged var latitude: NSNumber?
    @NSManaged var longitude: NSNumber?
    @NSManaged var searchResults: Data?
    @NSManaged var photoalbum: NSSet?

}
