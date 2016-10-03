//
//  Pin.swift
//  VirtualTourist
//
//  Created by James Jongsurasithiwat on 9/4/16.
//  Copyright © 2016 James Jongs. All rights reserved.
//

import CoreData
import MapKit

class Pin: NSManagedObject {

// Insert code here to add functionality to your managed object subclass
    convenience init(input: MKAnnotation, context: NSManagedObjectContext){
        let ent = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)
            self.init(entity: ent!, insertIntoManagedObjectContext: context)
            self.latitude = input.coordinate.latitude
            self.longitude = input.coordinate.longitude
    }
}
