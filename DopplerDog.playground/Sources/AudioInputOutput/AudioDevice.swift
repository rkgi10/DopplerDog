//
//  AudioDevice.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.

//

import Foundation
import CoreAudioKit

public class AudioDevice {
    public var id: AudioDeviceID;
    public var isInput: Bool;
    public var safetyOffset: UInt32;
    public var bufferSizeFrames: UInt32;
    public var format: AudioStreamBasicDescription;
    
    public init(devid: AudioDeviceID , isInput: Bool) {
        self.id = devid;
        self.isInput = isInput;
        self.safetyOffset = 0;
        self.bufferSizeFrames = 0;
        self.format = AudioStreamBasicDescription();
        
        if (self.id == kAudioDeviceUnknown) {
            return;
        }
        
        var propsize = UInt32(MemoryLayout<Float32>.size);
        
        let theScope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;
        
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertySafetyOffset,
            mScope: theScope,
            mElement: 0
        );
        
        checkErr(AudioObjectGetPropertyData(self.id, &theAddress, 0, nil, &propsize, &safetyOffset));
        
        propsize = UInt32(MemoryLayout<UInt32>.size);
        theAddress.mSelector = kAudioDevicePropertyBufferFrameSize;
        
        checkErr(AudioObjectGetPropertyData(self.id, &theAddress, 0, nil, &propsize, &bufferSizeFrames));
        
        propsize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size);
        theAddress.mSelector = kAudioDevicePropertyStreamFormat;
        
        checkErr(AudioObjectGetPropertyData(self.id, &theAddress, 0, nil, &propsize, &format));
    }
    
    public func setBufferSize(_ size: UInt32) {
        var size = size
        var propsize = UInt32(MemoryLayout<UInt32>.size);
        
        let theScope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;
        
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: theScope,
            mElement: 0
        );
        
        checkErr(AudioObjectSetPropertyData(self.id, &theAddress, 0, nil, propsize, &size));
        
        checkErr(AudioObjectGetPropertyData(self.id, &theAddress, 0, nil, &propsize, &bufferSizeFrames));
    }
    
    public func CountChannels() -> Int {
        var result : Int = 0;
        
        let theScope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;
        
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: theScope,
            mElement: 0
        );
        
        var propSize: UInt32 = 0;
        var err = AudioObjectGetPropertyDataSize(self.id, &theAddress, 0, nil, &propSize);
        if (err != noErr) {
            return 0;
        }
        
        let bufList = AudioBufferList.allocate(maximumBuffers: Int(propSize));
        err = AudioObjectGetPropertyData(self.id, &theAddress, 0, nil, &propSize, bufList.unsafeMutablePointer);
        if (err == noErr) {
            result = bufList.reduce(0, { $0 + Int($1.mNumberChannels) });
        }
        free(bufList.unsafeMutablePointer);
        return result;
    }
    
    public func name() -> String {
        let theScope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: theScope,
            mElement: 0
        );
        
        var maxlen = UInt32(1024);
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(maxlen));
        checkErr(AudioObjectGetPropertyData(self.id, &theAddress, 0, nil, &maxlen, buf));
        if let str = String(bytesNoCopy: buf, length: Int(maxlen), encoding: String.Encoding.utf8, freeWhenDone: true) {
            return str;
        }
        return "";
    }
}
