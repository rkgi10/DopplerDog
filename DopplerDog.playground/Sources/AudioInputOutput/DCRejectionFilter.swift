//
//  DCRejectionFilter.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//

import Foundation

class DCRejectionFilter {
    var x1: Float = 0;
    var y1: Float = 0;
    let kDefaultPoleDist: Float = 0.975;
    
    func processInplace(_ ioData: inout [Float]) {
        for i in 0...ioData.count-1 {
            let xCurr = ioData[i];
            ioData[i] = ioData[i] - x1 + (kDefaultPoleDist * y1);
            x1 = xCurr;
            y1 = ioData[i];
        }
    }
}
