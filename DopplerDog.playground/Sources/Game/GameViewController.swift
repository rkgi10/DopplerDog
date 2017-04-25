//
//  GameViewController.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//

import Cocoa
import SpriteKit
import GameplayKit

public class GameViewController: NSViewController {
//    public var umbrella : UmbrellaSprite = UmbrellaSprite()
    let options = [NSTrackingAreaOptions.mouseMoved, NSTrackingAreaOptions.activeInKeyWindow, NSTrackingAreaOptions.activeAlways, NSTrackingAreaOptions.inVisibleRect, ] as NSTrackingAreaOptions
    
    //doppler effect recognisers
//    var gestureRecognizer : GestureRecognizer!
    var soundPlayer : SoundFactory!


    
    override public func loadView() {
        self.view = SKView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let tracker = NSTrackingArea(rect: self.view.frame, options: options, owner: self.view, userInfo: nil)
        view.addTrackingArea(tracker)

    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
//        let sceneNode = GameScene(size: view.frame.size)
        let sceneNode = MenuScene(size: view.frame.size)
        sceneNode.scaleMode = .aspectFit
        sceneNode.sceneDidLoad()
        let skView = self.view as! SKView
        soundPlayer = SoundFactory(channels: 2, withFrequency: 20000, andAmplitude: 1.0, andVolume: 1.0, andPlay: true)
        skView.presentScene(sceneNode)
        skView.ignoresSiblingOrder = true
        
//        skView.showsPhysics = true
//        skView.showsFPS = true
//        skView.showsNodeCount = true
        
        //Play sound from sound manager
        SoundManager.sharedInstance.startPlaying()
    }

    
}

public var gameWindow = GameViewController()
