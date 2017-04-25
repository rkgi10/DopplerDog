//
//  AudioDeviceList.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.

//

import Foundation
import CoreAudio

public class Device : NSObject {
    public var name: String;
    public var id: AudioDeviceID;
    
    public init(name: String, id: AudioDeviceID) {
        self.name = name;
        self.id = id;
    }
}

public class AudioDeviceList {
    public var devices: [Device] = [];
    public var areInputs: Bool = false;
    
    public init(areInputs: Bool) {
        self.areInputs = areInputs;
        buildList();
    }
    
    public func buildList() {
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        );
        
        var propsize: UInt32 = 0;
        checkErr(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &theAddress, 0, nil, &propsize));
        let nDevices = Int(propsize) / MemoryLayout<AudioDeviceID>.size;
        
        var devids = Array<AudioDeviceID>(repeating: 0, count: nDevices);
        devids.withUnsafeMutableBufferPointer {
            (buffer: inout UnsafeMutableBufferPointer<AudioDeviceID>) -> () in
            checkErr(AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &theAddress,
                0,
                nil,
                &propsize,
                buffer.baseAddress! )
            );
        }
        
        devices = devids
            .map { AudioDevice(devid: $0, isInput: areInputs) }
            .filter { $0.CountChannels() > 0 }
            .map { Device(name: $0.name(), id: $0.id) }
    }
}
