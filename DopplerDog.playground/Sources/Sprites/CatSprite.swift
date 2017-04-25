//
//  GameScene.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//
import SpriteKit

public class CatSprite : SKSpriteNode {
    private let movementSpeed : CGFloat = 300.0
    private var timeSinceLastHit : TimeInterval = 2
    private let maxFlailTime : TimeInterval = 2
    private var currentRainHits = 4
    private let maxRainHits = 4
    private let walkingActionKey = "action_walking"
    private let walkFrames = [
        SKTexture(imageNamed: "dog_one"),
        SKTexture(imageNamed: "dog_two")
    ]
    
    private let meowSFX = [
        "cat_meow_1.mp3",
        "cat_meow_2.mp3",
        "cat_meow_3.mp3",
        "cat_meow_4.mp3",
        "cat_meow_5.wav",
        "cat_meow_6.wav"
    ]
    
    private let barkSFX = [
        "dog_bark_10.mp3",
        "dog_bark_9.mp3",
        "dog_bark_8.mp3",
        "dog_bark_7.mp3",
        "dog_bark_6.mp3",
        "dog_bark_5.mp3",
        "dog_bark_4.mp3",
        "dog_bark_3.mp3",
        "dog_bark_2.mp3",
        "dog_bark_1.mp3",]
    
    public static func newInstance() -> CatSprite {
        let catSprite = CatSprite(imageNamed: "dog_one")
        
        catSprite.zPosition = 3
        catSprite.physicsBody = SKPhysicsBody(circleOfRadius: catSprite.size.width / 2)
        
        catSprite.physicsBody?.categoryBitMask = CatCategory
        catSprite.physicsBody?.contactTestBitMask = RainDropCategory | WorldFrameCategory
        
        return catSprite
    }
    
    public func update(deltaTime : TimeInterval, foodLocation : CGPoint) {
        
        //walking action incorporating stunning when hit by rain
        timeSinceLastHit += deltaTime
        
        if timeSinceLastHit >= maxFlailTime {
            if action(forKey: walkingActionKey) == nil {
                let walkingAction = SKAction.repeatForever(
                    SKAction.animate(with: walkFrames,
                                     timePerFrame: 0.1,
                                     resize: false,
                                     restore: true))
                
                run(walkingAction, withKey:walkingActionKey)
            }
        
        //move towards food
            if foodLocation.x < position.x {
                //Food is left
                physicsBody?.velocity.dx = -movementSpeed
                xScale = -1
            } else {
                //Food is right
                physicsBody?.velocity.dx = movementSpeed
                xScale = 1
            }
        }
        
        if zRotation != 0 && action(forKey: "action_rotate") == nil {
            run(SKAction.rotate(toAngle: 0, duration: 0.25), withKey: "action_rotate")
        }
    
    }
    
    public func hitByRain() {
        timeSinceLastHit = 0
        removeAction(forKey: walkingActionKey)
        
        //cat mewoing muted when global mute
        if SoundManager.sharedInstance.isMuted {
            return
        }
        
        //Determine if we should meow or not
        if(currentRainHits < maxRainHits) {
            currentRainHits += 1
            
            return
        }

        if action(forKey: "action_sound_effect") == nil {
            currentRainHits = 0
            
            let selectedSFX = Int(arc4random_uniform(UInt32(barkSFX.count)))
            
            run(SKAction.playSoundFileNamed(barkSFX[selectedSFX], waitForCompletion: true),
                withKey: "action_sound_effect")
        }
    }


}
