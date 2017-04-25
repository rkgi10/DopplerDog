//
//  SpectralViewController.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import Foundation
import AppKit

public class SpectralViewController : NSViewController {
    
//    var frequencyGenerator : FrequencyGenerator!
    var gestureRecognizer : GestureRecognizer!
    var soundPlayer : SoundFactory!
    var spectralView : ZoomedSpectralView!
    
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 1024, height: 500))
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        soundPlayer = SoundFactory(channels: 2, withFrequency: 20000, andAmplitude: 1.0, andVolume: 1.0, andPlay: true)
        sleep(6)
        spectralView = ZoomedSpectralView(frame: self.view.bounds)
        spectralView.wantsLayer = true
        spectralView.layer?.backgroundColor = NSColor.black.cgColor
        self.view.addSubview(spectralView)
        
        let callback = {
            (fftSpectrum : [FFTArrayType])->Void in
            self.gotSpectrum(spectrum: fftSpectrum)
        }
        
        gestureRecognizer = GestureRecognizer(startRecognizing: true, numberOfBands: 1024, threshold: 4, callback: callback)
//        let square = NSView(frame: NSRect(x: 0, y: 0, width: 120.0, height: 120.0))
//        square.wantsLayer = true
//        square.layer?.backgroundColor = NSColor.red.cgColor
//        self.view.wantsLayer = true
//        self.view.layer?.backgroundColor = NSColor.black.cgColor
//        self.view.addSubview(square)

    }
    
    func gotSpectrum(spectrum : [FFTArrayType])
    {
//        spectralView.fft = spectrum
        DispatchQueue.main.async {
            self.spectralView.fft = spectrum
            self.spectralView.needsDisplay = true
        }
        
    }
    
}

public let spectralWindow = SpectralViewController()
