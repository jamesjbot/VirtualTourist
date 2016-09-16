//
//  Photo+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/15/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Photo {

    @NSManaged var imageData: NSData?
    @NSManaged var pin: Pin?

}
