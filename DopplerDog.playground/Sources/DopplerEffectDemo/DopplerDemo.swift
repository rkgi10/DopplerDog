//
//  DopplerDemo.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import Foundation
import AppKit

public class DopplerDemo : NSViewController {
    
//    var frequencyGenerator : FrequencyGenerator!
    var gestureRecognizer : GestureRecognizer!
    var soundPlayer : SoundFactory!
    var demoBox : DemoBox!
    var callback : (([FFTArrayType])->Void)!
    var pullCallback : ((Gesture)->Void)!
    var pushCallback : ((Gesture)->Void)!
    var pullCount = 0
    var pushCount = 0
    var pullAccumulator = 0
    var pushAccumulator = 0
    
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        soundPlayer = SoundFactory(channels: 2, withFrequency: 20000, andAmplitude: 1.0, andVolume: 1.0, andPlay: true)
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.black.cgColor
        
        self.demoBox = DemoBox(frame: NSRect(x: 225, y: 225, width: 100, height: 100))
        demoBox.wantsLayer = true
        self.view.addSubview(demoBox)
        demoBox.magnitude = 0
        
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: mouseClicked)
        
        callback = {
            (fftSpectrum : [FFTArrayType])->Void in
        }
        
        pullCallback = {
            (gesture : Gesture)-> Void in
            self.pullGestureIdentified(gesture: gesture)
        }
        
        pushCallback = {
            (gesture : Gesture) -> Void in
            self.pushGestureIdentified(gesture: gesture)
        }
        
        //        let square = NSView(frame: NSRect(x: 0, y: 0, width: 120.0, height: 120.0))
        //        square.wantsLayer = true
        //        square.layer?.backgroundColor = NSColor.red.cgColor
        //        self.view.wantsLayer = true
        //        self.view.layer?.backgroundColor = NSColor.black.cgColor
        //        self.view.addSubview(square)
        
    }
    
    func mouseClicked(event : NSEvent)->NSEvent
    {
        gestureRecognizer = GestureRecognizer(startRecognizing: true, numberOfBands: 1024, threshold: 3, callback: callback, pullCallback: pullCallback, pushCallback: pushCallback)
        self.demoBox.needsDisplay = true
//        self.demoBox.rotate(byDegrees: CGFloat(50))
//        self.demoBox.alphaValue = 0.3
        return event
    }
    func pullGestureIdentified(gesture : Gesture){
        pullCount += 1
        pullAccumulator += gesture.magnitude
        if pullCount > 2
        {
//        print("pull received")
        DispatchQueue.main.async {
            self.demoBox.removeFromSuperview()
            self.demoBox.frame.origin.x += CGFloat((16.0 * Float(gesture.magnitude)))
            self.view.addSubview(self.demoBox)
            self.pullCount = 0
            self.pullAccumulator = 0
            self.pushCount = 0
            self.pushAccumulator = 0
        }
        }
        
    }
    
    func pushGestureIdentified(gesture : Gesture){
        pushAccumulator += -(gesture.magnitude)
        pushCount += 1
        if pushCount > 2 {
//        print("push received")
        DispatchQueue.main.async {
            self.demoBox.removeFromSuperview()
            self.demoBox.frame.origin.x -= CGFloat((32.0 * Float(gesture.magnitude)))
            self.view.addSubview(self.demoBox)
            self.pullCount = 0
            self.pullAccumulator = 0
            self.pushCount = 0
            self.pushAccumulator = 0
        }
        }
        
    }
    
//    func gotSpectrum(spectrum : [FFTArrayType])
//    {
//        //        spectralView.fft = spectrum
//        DispatchQueue.main.async {
//            self.spectralView.fft = spectrum
//            self.spectralView.needsDisplay = true
//        }
//        
//    }
    
}

public let dopplerDemo = DopplerDemo()
