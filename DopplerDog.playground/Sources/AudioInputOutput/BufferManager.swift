//
//  BufferManager.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//

import Foundation

class BufferManager {
    var fftInputBuffer: [Float];
    var fftHelper: FFTHelper;
    var needsNewFFTData: Int32;
    var hasNewFFTData: Int32;
    let fftInputBufferLen: Int;
    let sampleRate: Float64;
    
    init(inMaxFramesPerSlice: Int, sampleRate: Float64) {
        fftInputBufferLen = inMaxFramesPerSlice;
        self.sampleRate = sampleRate;
        fftInputBuffer = [];
        fftHelper = FFTHelper(inMaxFramesPerSlice: inMaxFramesPerSlice);
        needsNewFFTData = 0;
        hasNewFFTData = 0;
        OSAtomicIncrement32Barrier(&needsNewFFTData);
    }
    
    func fftOutputBufferLength() -> Int { return fftInputBufferLen / 2; }
    
    func copyAudioDataToFFTInputBuffer(_ inData: [Float]) {
        let framesToCopy = min(inData.count, fftInputBufferLen - fftInputBuffer.count);
        fftInputBuffer.append(contentsOf: inData.prefix(framesToCopy));
        if (fftInputBuffer.count >= fftInputBufferLen) {
            OSAtomicIncrement32(&hasNewFFTData);
            OSAtomicDecrement32(&needsNewFFTData);
        }
    }
    
    func fftOutput() -> [Float] {
        let outFFTData = fftHelper.computeFFT(fftInputBuffer);
        fftInputBuffer.removeAll();
        OSAtomicDecrement32Barrier(&hasNewFFTData);
        OSAtomicIncrement32Barrier(&needsNewFFTData);
        return outFFTData;
    }
}
