//
//  VerifyNoErr.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//

import Foundation

@discardableResult
public func checkErr(_ err : @autoclosure () -> OSStatus, file: String = #file, line: Int = #line) -> OSStatus! {
    let error = err()
    if (error != noErr) {
        print("CAPlayThrough Error: \(error) ->  \(file):\(line)\n");
        return error
    }
    return nil;
}
