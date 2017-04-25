//
//  SpectralView.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import Foundation
import AppKit
public class SpectralView : NSView {
    
    var fft : [FFTArrayType]?
    
    override public func draw(_ dirtyRect: NSRect) {
        if fft == nil {
            return
        }
        
        let context = NSGraphicsContext.current()?.cgContext
        self.drawSpectrum(context : context!)
        self.drawLabels(context : context!)
    }
    
    func drawSpectrum(context: CGContext) {
        let viewWidth = self.bounds.size.width
        let viewHeight = self.bounds.size.height
        let plotYStart: CGFloat = 48.0
        
        context.saveGState()
//        context.scaleBy(x: 1, y: -1)
//        context.translateBy(x: 0, y: -viewHeight)
        
        let colors = [NSColor.green.cgColor,NSColor.blue.cgColor, NSColor.yellow.cgColor, NSColor.red.cgColor]
        let gradient = CGGradient(
            colorsSpace: nil, // generic color space
            colors: colors as CFArray,
            locations: [0.0,0.25 , 0.50, 0.75])
        
        var x: CGFloat = 0.0
        
        let count = fft?.count
        
        // Draw the spectrum.
//        let maxDB: Float = 64.0
//        let minDB: Float = -32.0
        let headroom : Float = 100.0
        let colWidth = viewWidth / CGFloat(count!)
//        print("Col width is\(colWidth)")
        
        for i in 0..<count! {
            let magnitude = fft?[i].magnitudeAtBin
//            print("frequency \(fft?[i].frequencyAtBin) ** magnitude \(magnitude)")
//            if magnitude! > 1000
//            {
//                magnitude = 1000.0
//            }
            
            // Incoming magnitudes are linear, making it impossible to see very low or very high values. Decibels to the rescue!
//            var magnitudeDB = TempiFFT.toDB(magnitude)
            
            // Normalize the incoming magnitude so that -Inf = 0
//            magnitudeDB = max(0, magnitudeDB + abs(minDB))
            
            let dbRatio = min(1.0, magnitude! / headroom)
            let magnitudeNorm = CGFloat(dbRatio) * (viewHeight)
            
            let colRect: CGRect = CGRect(x: x, y: plotYStart, width: CGFloat(colWidth), height: magnitudeNorm)
            
            let startPoint = CGPoint(x: viewWidth / 2, y: 0)
            let endPoint = CGPoint(x: viewWidth / 2, y: viewHeight)
            
            context.saveGState()
            context.clip(to: colRect)
            context.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: CGGradientDrawingOptions(rawValue: 0))
            context.restoreGState()
            
            x += colWidth
        }
        
//        context.restoreGState()
    }
    
    private func drawLabels(context: CGContext) {
        let viewWidth = self.bounds.size.width
//        let viewHeight = self.bounds.size.height
        
        context.saveGState()
//        context.translateBy(x: 0, y: viewHeight);
        
        let pointSize: CGFloat = 15.0
        let font = NSFont.systemFont(ofSize: pointSize, weight: NSFontWeightRegular)
        
        let freqLabelStr = "Frequency (kHz)"
        var attrStr = NSMutableAttributedString(string: freqLabelStr)
        attrStr.addAttribute(NSFontAttributeName, value: font, range: NSMakeRange(0, freqLabelStr.characters.count))
        attrStr.addAttribute(NSForegroundColorAttributeName, value: NSColor.yellow, range: NSMakeRange(0, freqLabelStr.characters.count))
        
        var x: CGFloat = viewWidth / 2.0 - attrStr.size().width / 2.0
        attrStr.draw(at: CGPoint(x: x, y: 20))
        
        let labelStrings: [String] = ["5", "10", "15", "20"]
        let labelValues: [CGFloat] = [5000, 10000, 15000, 20000]
        let samplesPerPixel: CGFloat = CGFloat(22050 / viewWidth)
        for i in 0..<labelStrings.count {
            let str = labelStrings[i]
            let freq = labelValues[i]
            
            attrStr = NSMutableAttributedString(string: str)
            attrStr.addAttribute(NSFontAttributeName, value: font, range: NSMakeRange(0, str.characters.count))
            attrStr.addAttribute(NSForegroundColorAttributeName, value: NSColor.yellow, range: NSMakeRange(0, str.characters.count))
            
            x = freq / samplesPerPixel - pointSize / 2.0
            attrStr.draw(at: CGPoint(x: x, y: 40))
        }
        
        context.restoreGState()
    }

}
