//
//  GestureRecogniser.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import Foundation
import Cocoa
import AVFoundation
import CoreAudio

public enum GestureType {
    case push
    case pull
    case tap
}

public struct Gesture {
    var gesture : GestureType
    var magnitude : Int
    
    init(gesture : GestureType, magnitude : Int) {
        self.gesture = gesture
        self.magnitude = magnitude
    }
}

public struct FFTArrayType : Comparable {
    var frequencyAtBin : Float
    var magnitudeAtBin : Float
    
    init(frequency : Float, magnitude : Float)
    {
        self.frequencyAtBin = frequency
        self.magnitudeAtBin = magnitude
    }
}

public func ==(struct1 : FFTArrayType, struct2 : FFTArrayType)->Bool
{
    return struct1.magnitudeAtBin == struct2.magnitudeAtBin
}

public func <(struct1 : FFTArrayType, struct2 : FFTArrayType)->Bool
{
    return struct1.magnitudeAtBin < struct2.magnitudeAtBin
}

public func >(struct1 : FFTArrayType, struct2 : FFTArrayType)->Bool
{
    return struct1.magnitudeAtBin > struct2.magnitudeAtBin
}


public class GestureRecognizer {
    
    //variables required ahead
    var inputDevice: AudioDeviceID = 0;
    var outputDevice: AudioDeviceID = 0;
    var propsize : UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)
    let maxDB: Float = 64.0
    let minDB: Float = -8.0
    var osErr: OSStatus = 0
    var callback : CAPlayThroughCallback!
    var spectrumCallback : ((_ spectrum : [FFTArrayType])->Void)
    var pullCallback : ((_ gesture : Gesture)->Void)!
    var pushCallback : ((_ gesture : Gesture)->Void)!
    var numberOfBands : Int = 32
    var threshold : Int = 4
    var playThrough : CAPlayThrough!
    var dominantFrequency : Float = 20000.0
    var maxAmp : Float = 0.0
    var minAmp : Float = 100.0
    var avgPower : Float = 0.0
    
    
    var theAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
    );
    
    public init(startRecognizing : Bool, numberOfBands : Int, threshold : Int, callback : @escaping (_ spectrum : [FFTArrayType])->Void, pullCallback : @escaping (_ gesture : Gesture)->Void, pushCallback : @escaping (_ gesture : Gesture)->Void) {
        self.spectrumCallback = callback
        self.pullCallback = pullCallback
        self.pushCallback = pushCallback
        basicSetup()
        self.numberOfBands = numberOfBands
        self.threshold = threshold
        if startRecognizing {
            if !playThrough.isRunning() {
                osErr = playThrough.startRecording()
                assert(osErr == noErr, "*** AudioUnitRender err \(osErr)")
            }
            
            //once recording starts, control will pass to callback, which in turn will call gotSomeAudio
            
        }
    }
    
    public init(startRecognizing : Bool, numberOfBands : Int, threshold : Int, callback : @escaping (_ spectrum : [FFTArrayType])->Void) {
        self.spectrumCallback = callback
//        self.pullCallback = 
//        self.pushCallback = callback
        basicSetup()
        self.numberOfBands = numberOfBands
        self.threshold = threshold
        if startRecognizing {
            if !playThrough.isRunning() {
                osErr = playThrough.startRecording()
                assert(osErr == noErr, "*** AudioUnitRender err \(osErr)")
            }
            
            //once recording starts, control will pass to callback, which in turn will call gotSomeAudio
            
        }
    }
    
    func basicSetup()
    {
        //get the inputdevice
        propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        checkErr(AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &theAddress,
            0,
            nil,
            &propsize,
            &inputDevice)
        );
        
        //get the output device
        propsize = UInt32(MemoryLayout<AudioDeviceID>.size);
        theAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
        checkErr(AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &theAddress,
            0,
            nil,
            &propsize,
            &outputDevice)
        );
        
        //intialising the callback
        callback = {
            (timeStamp, numberOfFrames, samples) -> Void in
            self.gotSomeAudio(timeStamp: timeStamp, numberOfFrames: Int(numberOfFrames), samples: samples)
        }
        
        //setup audio-recording and buffers
        playThrough = CAPlayThrough(input: inputDevice, output: outputDevice, callback: callback)
        

    }
    
    
    
    func getLimitedSpectrumFromFFT(fft : TempiFFT, lowerFrequency : Float, higherFrequency : Float)->[FFTArrayType]
    {
        var fftArray : [FFTArrayType] = []
        let lowerindexguess = Int(((lowerFrequency / 22050.0) * Float(fft.numberOfBands)).rounded(.down))
        let upperindexguess = fft.numberOfBands - 1
        
//        print("differences in indexes")
//        print(upperindexguess-lowerindexguess)
        for i in lowerindexguess...upperindexguess {
            let magnitude = fft.magnitudeAtBand(i)
            let frequency = fft.frequencyAtBand(i)
            let magnitudeDB = TempiFFT.toDB(magnitude)
//            magnitudeDB = max(0, magnitudeDB + abs(minDB))
            fftArray.append(FFTArrayType(frequency: frequency, magnitude: magnitudeDB))
        }
        return fftArray
    }
    
    func getSpectrumFromFFT(fft : TempiFFT, count : Int)->[FFTArrayType]
    {
        var fftArray : [FFTArrayType] = []

        
        for i in 0..<count {
            let magnitude = fft.magnitudeAtBand(i)
            let frequency = fft.frequencyAtBand(i)
            var magnitudeDB = TempiFFT.toDB(magnitude)
            magnitudeDB = max(0, magnitudeDB + abs(minDB))
            fftArray.append(FFTArrayType(frequency: frequency, magnitude: magnitudeDB))
            if(i > 923 && i < 935)
            {
//                print("Frequency : \(fftArray[i].frequencyAtBin) ** Magnitude : \(fftArray[i].magnitudeAtBin)")
            }
        }
        return fftArray
    }
    
    func gotSomeAudio(timeStamp: Double, numberOfFrames: Int, samples: [Float]) {
        let fft = TempiFFT(withSize: numberOfFrames, sampleRate: 44100.0)
        fft.windowType = TempiFFTWindowType.hanning
        fft.fftForward(samples)
        fft.calculateLinearBands(minFrequency: 0, maxFrequency: fft.nyquistFrequency, numberOfBands: self.numberOfBands)
        let spectrum = getSpectrumFromFFT(fft: fft, count: self.numberOfBands)
        let power = fft.averageMagnitude(lowFreq: 5000, highFreq: 15000)
//        print("normal power \(avgPower)")
        if(spectrum[929].magnitudeAtBin < 55)
        {
//            if spectrum[924].magnitudeAtBin > 0.3 * spectrum[929].magnitudeAtBin {
//                print("Pull received")
//            }
//            if spectrum[934].magnitudeAtBin > 0.3 * spectrum[929].magnitudeAtBin {
//                print("Push received")
//            }
            recogniseGesture(fft: fft, spectrum: spectrum, thresholdBandwidth: self.threshold, power : power)
            spectrumCallback(spectrum)
        }
//      print(spectrum)
//        print(timeStamp)
//        dominantFrequency = (spectrum.max()?.frequencyAtBin)!
//        print("Dominant frequency is")
//        print(dominantFrequency)
//

    }
    
    func recogniseGesture(fft : TempiFFT, spectrum : [FFTArrayType], thresholdBandwidth : Int, power : Float)
    {
        let relevantWindow = 33
        var normalisedMagnitude : Float = 0.0
        let primaryindexguess = Int((20000 * 0.0464399093).rounded(.up))
        var magnitudeDB : Float = 0.0
        
//        if primaryindexguess > (fft.numberOfBands - 1) {
//            primaryindexguess = fft.numberOfBands - 1
//        }
        let primaryMagnitudeDB = spectrum[primaryindexguess].magnitudeAtBin
//        print("primary magnitude")
//        print(primaryMagnitudeDB)
        
        
        
        var leftBandwidth = 0
        var rightBandwidth = 0
        let leftMagnitudeRatio : Float = 0.1
        let rightMagnitudeRatio : Float = 0.1
        let rightThreshold : Int = self.threshold
        let leftThreshold : Int = self.threshold
        
        repeat {
            leftBandwidth += 1
            magnitudeDB = spectrum[primaryindexguess - leftBandwidth].magnitudeAtBin
            normalisedMagnitude = magnitudeDB / primaryMagnitudeDB
//            print("NormVol** AbsVol ** FreqAtBin ** Left Band")
//            print("\(normalisedMagnitude) **\(magnitudeDB) **\(spectrum[primaryindexguess - leftBandwidth].frequencyAtBin) \(leftBandwidth)")
//            minAmp = min(minAmp, magnitudeDB)
//            maxAmp = max(maxAmp, magnitudeDB)
        } while ((normalisedMagnitude > leftMagnitudeRatio) && (leftBandwidth < relevantWindow))
        
        repeat {
            rightBandwidth += 1
            magnitudeDB = spectrum[primaryindexguess + rightBandwidth].magnitudeAtBin
            normalisedMagnitude = magnitudeDB / primaryMagnitudeDB
//            print("NormVol** AbsVol ** FreqAtBin ** Right Band")
//            print("\(normalisedMagnitude) **\(magnitudeDB) **\(spectrum[primaryindexguess + rightBandwidth].frequencyAtBin)  ** \(rightBandwidth)")
//            minAmp = min(minAmp, magnitudeDB)
//            maxAmp = max(maxAmp, magnitudeDB)
        } while ((normalisedMagnitude > rightMagnitudeRatio) && (rightBandwidth < relevantWindow))
//
        if(leftBandwidth > leftThreshold || rightBandwidth > rightThreshold)
        {
            if power > 10 * self.avgPower {
//                print("******Clap Detected#####")
            }
            self.avgPower = power
            let diff = leftBandwidth - rightBandwidth
            if diff > 0 {
                
//                print("pull detected with magnitude \(diff)")
                if self.pullCallback != nil
                {
//                    print("pull passed")
                    let gestureToBePassed = Gesture(gesture: .pull, magnitude: diff)
                    self.pullCallback(gestureToBePassed)
                }
            }
            if diff < 0 {
//                print("push detected with magnitude \(abs(diff))")
//                for i in 923...936
//                {
//                    print("Frequency : \(spectrum[i].frequencyAtBin) ** Magnitude : \(spectrum[i].magnitudeAtBin)")
//                }
                if self.pushCallback != nil
                {
//                    print("push passed")
                    let gestureToBePassed = Gesture(gesture: .push, magnitude: abs(diff))
                    self.pushCallback(gestureToBePassed)
                }

            }
            else if diff == 0 {
//                print("cancelled out")
            }
//            print("pull magnitude \(leftBandwidth - leftThreshold) ** push magnitude \(rightBandwidth - rightThreshold)")
        }
//        print("Max Amp \(maxAmp) ** Min Amp\(minAmp)")
}
    
    
    
    
    

    
}

