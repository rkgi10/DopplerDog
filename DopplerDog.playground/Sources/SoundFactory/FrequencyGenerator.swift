//
//  FrequencyGenerator.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import Foundation
import AVFoundation

public class FrequencyGenerator : AVAudioPlayerNode {
    
    let bufferCapacity : UInt32 = 2048
    public var sampleRate : Double = 44100.00
    
    public var frequency = 440.0   //f-frequency
    public var amplitude = 1.0     //A-amplitude
    
    var theta = 0.0         //theta-phase angle
    var audioFormat : AVAudioFormat!
    
    //initialise the frequency generator, and set the audioformat
    public override init() {
        super.init()
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: self.sampleRate, channels: 2)
    }
    
    
    func constructBuffer()->AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bufferCapacity)
        loadBuffer(buffer: buffer)
        return buffer
    }
    
    func loadBuffer(buffer:AVAudioPCMBuffer){
        let data =  buffer.floatChannelData?[0]
        let numberOfFrames = buffer.frameCapacity
        
        var theta = self.theta
        let deltaTheta = (2.0 * M_PI * self.frequency)/(self.sampleRate)
        
        for frame in 0..<Int(numberOfFrames){
            data?[frame] = (Float32(sin(theta)*amplitude))
            
            theta += deltaTheta
            if theta > 2.0 * M_PI {
                theta -= 2.0 * M_PI
            }
        }
        buffer.frameLength = numberOfFrames
        self.theta = theta
    }
    
    func scheduleBuffer() {
        let buffer = constructBuffer()
        self.scheduleBuffer(buffer) {
            if self.isPlaying {
                self.scheduleBuffer()
            }
        }
    }
    
    public func preparePlaying() {
        scheduleBuffer()
        scheduleBuffer()
        scheduleBuffer()
        scheduleBuffer()
        scheduleBuffer()
    }
    
    
}
