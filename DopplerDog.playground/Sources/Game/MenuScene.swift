//
//  GameScene.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import SpriteKit

class MenuScene : SKScene {
    let startButtonTexture = SKTexture(imageNamed: "button_start")
    let startButtonPressedTexture = SKTexture(imageNamed: "button_start_pressed")
    let soundButtonTexture = SKTexture(imageNamed: "speaker_on")
    let soundButtonTextureOff = SKTexture(imageNamed: "speaker_off")
    
    let logoSprite = SKSpriteNode(imageNamed: "logo2")
    var startButton : SKSpriteNode! = nil
    var soundButton : SKSpriteNode! = nil
    
    let highScoreNode = SKLabelNode(fontNamed: "PixelDigivolve")
    let instructionNode1 = SKLabelNode(text: "This game can be played using <-- and --> keys on keyboard")
    let instructionNode2 = SKLabelNode(text: "And using left and right gestures above the keyboard")
    
    var selectedButton : SKSpriteNode?
    
    //doppler gesture-recogniser
    var gestureRecognizer : GestureRecognizer!
    
    override func sceneDidLoad() {
        backgroundColor = SKColor(red:0.30, green:0.81, blue:0.89, alpha:1.0)
        
        //Setup logo - sprite initialized earlier
        logoSprite.position = CGPoint(x: size.width / 2, y: size.height / 2 + 100)
        addChild(logoSprite)
        
        //Setup start button
        startButton = SKSpriteNode(texture: startButtonTexture)
        startButton.position = CGPoint(x: size.width / 2, y: size.height / 2 - startButton.size.height / 2)
        addChild(startButton)
        
        let edgeMargin : CGFloat = 25
        //Setup sound button
        soundButton = SKSpriteNode(texture: SoundManager.sharedInstance.isMuted ? soundButtonTextureOff : soundButtonTexture)
        soundButton.position = CGPoint(x: size.width - soundButton.size.width / 2 - edgeMargin, y: soundButton.size.height / 2 + edgeMargin)
        addChild(soundButton)
        
        instructionNode1.fontSize = 16
        instructionNode1.fontName = "Avenir-Black"
        instructionNode1.verticalAlignmentMode = .bottom
        instructionNode1.position = CGPoint(x: size.width / 2 , y: soundButton.size.height + edgeMargin)
        addChild(instructionNode1)
        
        instructionNode2.fontSize = 16
        instructionNode2.fontName = "Avenir-Black"
        instructionNode2.verticalAlignmentMode = .bottom
        instructionNode2.position = CGPoint(x: size.width / 2 , y: soundButton.size.height + edgeMargin - 17)
        addChild(instructionNode2)
        
        //Setup high score node
        let defaults = UserDefaults.standard
        
        let highScore = defaults.integer(forKey: ScoreKey)
        
        highScoreNode.text = "\(highScore)"
        highScoreNode.fontSize = 70
        highScoreNode.verticalAlignmentMode = .top
        highScoreNode.position = CGPoint(x: size.width / 2, y: startButton.position.y - startButton.size.height / 2 - 50)
        highScoreNode.zPosition = 1
        addChild(highScoreNode)
    }
    
    override func mouseDown(with event: NSEvent) {
        
        if selectedButton != nil {
            handleStartButtonHover(isHovering: false)
            handleSoundButtonHover(isHovering: false)
        }
        
        if startButton.contains(event.location(in: self)) {
            selectedButton = startButton
            handleStartButtonHover(isHovering: true)
        } else if soundButton.contains(event.location(in: self)) {
            selectedButton = soundButton
            handleSoundButtonHover(isHovering: true)
        }
    }
    
    
    override func mouseMoved(with event: NSEvent) {
//        let touchPoint = event.location(in: self)
        
        if selectedButton == startButton {
            handleStartButtonHover(isHovering: (startButton.contains(event.location(in: self))))
        } else if selectedButton == soundButton {
            handleSoundButtonHover(isHovering: (soundButton.contains(event.location(in: self))))
        }
        
        selectedButton = nil
    }
    
    override func mouseUp(with event: NSEvent) {
//        let touchPoint = event.location(in: self)
        
        if selectedButton == startButton {
            handleStartButtonHover(isHovering: false)
            
            if (startButton.contains(event.location(in: self))) {
                handleStartButtonClick()
            }
            
        } else if selectedButton == soundButton {
            handleSoundButtonHover(isHovering: false)
            
            if (soundButton.contains(event.location(in: self))) {
                handleSoundButtonClick()
            }
        }
        

    }

//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if let touch = touches.first {
//            if selectedButton != nil {
//                handleStartButtonHover(isHovering: false)
//                handleSoundButtonHover(isHovering: false)
//            }
//            
//            if startButton.contains(touch.location(in: self)) {
//                selectedButton = startButton
//                handleStartButtonHover(isHovering: true)
//            } else if soundButton.contains(touch.location(in: self)) {
//                selectedButton = soundButton
//                handleSoundButtonHover(isHovering: true)
//            }
//        }
//    }
//    
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if let touch = touches.first {
//            
//            if selectedButton == startButton {
//                handleStartButtonHover(isHovering: (startButton.contains(touch.location(in: self))))
//            } else if selectedButton == soundButton {
//                handleSoundButtonHover(isHovering: (soundButton.contains(touch.location(in: self))))
//            }
//        }
//    }
//    
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if let touch = touches.first {
//            
//            if selectedButton == startButton {
//                handleStartButtonHover(isHovering: false)
//                
//                if (startButton.contains(touch.location(in: self))) {
//                    handleStartButtonClick()
//                }
//                
//            } else if selectedButton == soundButton {
//                handleSoundButtonHover(isHovering: false)
//                
//                if (soundButton.contains(touch.location(in: self))) {
//                    handleSoundButtonClick()
//                }
//            }
//        }
//        
//        selectedButton = nil
//    }
    
    func handleStartButtonHover(isHovering : Bool) {
        if isHovering {
            startButton.texture = startButtonPressedTexture
        } else {
            startButton.texture = startButtonTexture
        }
    }
    
    func handleSoundButtonHover(isHovering : Bool) {
        if isHovering {
            soundButton.alpha = 0.5
        } else {
            soundButton.alpha = 1.0
        }
    }
    
    func handleStartButtonClick() {
        
//        let sceneNode = MenuScene(size: view.frame.size)
//        sceneNode.scaleMode = .aspectFit
//        sceneNode.sceneDidLoad()
//        
//        
//        skView.presentScene(sceneNode)
        
//        print("start button clicked")
        let transition = SKTransition.reveal(with: .down, duration: 0.75)
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = .resizeFill
        gameScene.sceneDidLoad()
        let skView = self.view!
        skView.presentScene(gameScene, transition: transition)
    }
    
    func handleSoundButtonClick() {
        if SoundManager.sharedInstance.toggleMute() {
            //Is muted
            soundButton.texture = soundButtonTextureOff
        } else {
            //Is not muted
            soundButton.texture = soundButtonTexture
        }
    }
}
