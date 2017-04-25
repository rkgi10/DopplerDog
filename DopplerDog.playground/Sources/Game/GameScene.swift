//
//  GameScene.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 01/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//

import SpriteKit
import GameplayKit
import AppKit
import CoreText

class GameScene: SKScene, SKPhysicsContactDelegate {
    private var lastUpdateTime : TimeInterval = 0
    private var currentRainDropSpawnTime : TimeInterval = 0
    private var rainDropSpawnRate : TimeInterval = 1.5
    private let random = GKARC4RandomSource()
    private let foodEdgeMargin : CGFloat = 75.0
    private let umbrellaEdgeMarginLeft : CGFloat = 75.0
    private let umbrellaEdgeMarginRight : CGFloat = 725.0
    private let umbrella = UmbrellaSprite.newInstance()
    private let rainDropTexture = SKTexture(imageNamed: "rain_drop")
    private var cat : CatSprite!
    private var food : FoodSprite!
    private let hud = HudNode()
    let fontURL = Bundle.main.url(forResource: "Pixel Digivolve", withExtension: "otf")
    var pixelDigivolve = NSFont(name: "Pixel Digivolve", size: 30)
    
    //doppler effect gesture recogniser
    var gestureRecognizer : GestureRecognizer!
    var callback : (([FFTArrayType])->Void)!
    var pullCallback : ((Gesture)->Void)!
    var pushCallback : ((Gesture)->Void)!
    var pullCount = 0
    var pushCount = 0
    var pullAccumulator = 0
    var pushAccumulator = 0

    
    
    override func sceneDidLoad() {
        //last update time : defines smoothness
        self.lastUpdateTime = 0
        
        //load custom fonts
        CTFontManagerRegisterFontsForURL(fontURL as! CFURL, CTFontManagerScope.process, nil)
        
        //adding text label
//        let label = SKLabelNode(fontNamed: "PixelDigivolve")
//        label.text = "Hello World!"
//        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
//        label.zPosition = 1000
//        addChild(label)
        
        //adding the Heads-up-display
        hud.setup(size: size)
        
        hud.quitButtonAction = {
            let transition = SKTransition.reveal(with: .up, duration: 0.75)
            
            let gameScene = MenuScene(size: self.size)
            gameScene.scaleMode = self.scaleMode
            gameScene.sceneDidLoad()
            
            self.view?.presentScene(gameScene, transition: transition)
            
            self.hud.quitButtonAction = nil
        }
        addChild(hud)
        //to establish a sightly larger CGRect around the world...detect collisions with it and remove the node
        var worldFrame = frame
        worldFrame.origin.x -= 100
        worldFrame.origin.y -= 100
        worldFrame.size.height += 200
        worldFrame.size.width += 200
        
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: worldFrame)
        self.physicsWorld.contactDelegate = self
        self.physicsBody?.categoryBitMask = WorldFrameCategory
        
        
        //add background
        let background = SKSpriteNode(imageNamed: "background2")
        background.position = CGPoint(x: frame.midX, y: frame.midY)
        background.zPosition = 0
        addChild(background)
        
        //add floor
        let floorNode = SKShapeNode(rectOf: CGSize(width: size.width, height: 5))
        floorNode.position = CGPoint(x: size.width / 2, y: 50)
//        floorNode.zPosition = 1
        floorNode.fillColor = SKColor.red
        floorNode.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -(size.width / 2) , y:0) , to: CGPoint(x: size.width / 2, y: 0))
        floorNode.physicsBody?.categoryBitMask = FloorCategory
        floorNode.physicsBody?.contactTestBitMask = RainDropCategory
        floorNode.physicsBody?.restitution = 0.3
        self.addChild(floorNode)
        
        //Add umbrella
        umbrella.updatePosition(point: CGPoint(x: frame.midX, y: frame.midY))
        umbrella.zPosition = 1
        addChild(umbrella)
        
        //spawn cat
        spawnCat()
        
        //spawn food
        spawnFood()
        
        
        //add raindrop-alpha version
        spawnRaindrop()
        
//        set-up gesture recognisers
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

         gestureRecognizer = GestureRecognizer(startRecognizing: true, numberOfBands: 1024, threshold: 3, callback: callback, pullCallback: pullCallback, pushCallback: pushCallback)
    }
    
    func pullGestureIdentified(gesture : Gesture){
        pullCount += 1
        pullAccumulator += gesture.magnitude
        if pullCount > 1
        {
//            print("pull received")
                self.pullCount = 0
                self.pullAccumulator = 0
                self.pushCount = 0
                self.pushAccumulator = 0
            var currPosition = umbrella.getCurrentPosition()
            currPosition.x += CGFloat((96.0 * Float(gesture.magnitude)))
            currPosition.x = min(currPosition.x, umbrellaEdgeMarginRight)
            umbrella.setDestination(destination: currPosition)
        
        }
        
    }
    
    func pushGestureIdentified(gesture : Gesture){
        pushAccumulator += -(gesture.magnitude)
        pushCount += 1
        if pushCount > 1 {
//            print("push received")
                self.pullCount = 0
                self.pullAccumulator = 0
                self.pushCount = 0
                self.pushAccumulator = 0
            var currPosition = umbrella.getCurrentPosition()
            currPosition.x -= CGFloat((384.0 * Float(gesture.magnitude)))
            currPosition.x = max(currPosition.x, umbrellaEdgeMarginLeft)
            umbrella.setDestination(destination: currPosition)
        }
        
    }

    
    func spawnFood() {
        self.food = FoodSprite.newInstance()
        var randomPosition : CGFloat = CGFloat(random.nextInt())
        randomPosition = randomPosition.truncatingRemainder(dividingBy: size.width - foodEdgeMargin * 2)
        randomPosition = CGFloat(abs(randomPosition))
        randomPosition += foodEdgeMargin
        
        food.position = CGPoint(x: randomPosition, y: size.height)
        
        addChild(food)
    }
    
    func spawnRaindrop()
    {
        let rainDrop = SKSpriteNode(texture: rainDropTexture)
//        let rainDrop = SKShapeNode(rectOf: CGSize(width: 20, height: 20))   old rain-drop
        rainDrop.zPosition = 2
        let randomPosition = abs(CGFloat(random.nextInt())).truncatingRemainder(dividingBy: size.width)
        rainDrop.position = CGPoint(x: randomPosition, y: size.height)
//        rainDrop.fillColor = SKColor.blue
        rainDrop.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 20))
//        rainDrop.physicsBody = SKPhysicsBody(texture: rainDropTexture, size: rainDrop.size)
        rainDrop.physicsBody?.categoryBitMask = RainDropCategory
        rainDrop.physicsBody?.contactTestBitMask = WorldFrameCategory
        rainDrop.physicsBody?.density = 0.5
        addChild(rainDrop)
    }
    
    func spawnCat() {
        if let currentCat = cat, children.contains(currentCat) {
            cat.removeFromParent()
            cat.removeAllActions()
            cat.physicsBody = nil
        }
        
        cat = CatSprite.newInstance()
        cat.position = CGPoint(x: umbrella.position.x, y: umbrella.position.y - 30)
        
        addChild(cat)
        
        //reset points
        hud.resetPoints()
    }
    
    override func keyDown(with event: NSEvent) {
//        print("keycode is \(event.keyCode)")
        if event.keyCode == 124 {
            var currPosition = umbrella.getCurrentPosition()
            currPosition.x += CGFloat(500.0)
            currPosition.x = min(currPosition.x, umbrellaEdgeMarginRight)
            umbrella.setDestination(destination: currPosition)
        }
        else if event.keyCode == 123 {
            var currPosition = umbrella.getCurrentPosition()
            currPosition.x -= CGFloat(500.0)
            currPosition.x = max(currPosition.x, umbrellaEdgeMarginLeft)
            umbrella.setDestination(destination: currPosition)
        }
    }
    override func mouseDown(with event: NSEvent) {
        let touchPoint = event.location(in: self)
        hud.touchBeganAtPoint(point: touchPoint)
        
//        if !hud.quitButtonPressed {
//            umbrella.setDestination(destination: touchPoint)
//        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let touchPoint = event.location(in: self)
        hud.touchMovedToPoint(point: touchPoint)
        
//        if !hud.quitButtonPressed {
//            umbrella.setDestination(destination: touchPoint)
//        }
    }
    
    override func mouseUp(with event: NSEvent) {
        let touchPoint = event.location(in: self)
        hud.touchEndedAtPoint(point: touchPoint)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Initialize _lastUpdateTime if it has not already been
        if (self.lastUpdateTime == 0) {
            self.lastUpdateTime = currentTime
        }
        
        // Calculate time since last update
        let dt = currentTime - self.lastUpdateTime
        self.currentRainDropSpawnTime += dt
        
        if currentRainDropSpawnTime > rainDropSpawnRate {
            currentRainDropSpawnTime = 0
            spawnRaindrop()
        }
        umbrella.update(deltaTime: dt)
        cat.update(deltaTime: dt, foodLocation: food.position)
        self.lastUpdateTime = currentTime
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        
        //rain-drop collision detection
        if (contact.bodyA.categoryBitMask == RainDropCategory) {
            contact.bodyA.node?.physicsBody?.collisionBitMask = 0
        } else if (contact.bodyB.categoryBitMask == RainDropCategory) {
            contact.bodyB.node?.physicsBody?.collisionBitMask = 0
        }
        
        //handling food eating/collisions
        if contact.bodyA.categoryBitMask == FoodCategory || contact.bodyB.categoryBitMask == FoodCategory {
            handleFoodHit(contact: contact)
            return
        }
        
        //handling cat collision
        if contact.bodyA.categoryBitMask == CatCategory || contact.bodyB.categoryBitMask == CatCategory {
            handleCatCollision(contact: contact)
            
            return
        }
        
        //checking for collision with the world rect
        if contact.bodyA.categoryBitMask == WorldFrameCategory {
            contact.bodyB.node?.removeFromParent()
            contact.bodyB.node?.physicsBody = nil
            contact.bodyB.node?.removeAllActions()
        } else if contact.bodyB.categoryBitMask == WorldFrameCategory {
            contact.bodyA.node?.removeFromParent()
            contact.bodyA.node?.physicsBody = nil
            contact.bodyA.node?.removeAllActions()
        }
    }
    
    func handleCatCollision(contact: SKPhysicsContact) {
        var otherBody : SKPhysicsBody
        
        if contact.bodyA.categoryBitMask == CatCategory {
            otherBody = contact.bodyB
        } else {
            otherBody = contact.bodyA
        }
        
        switch otherBody.categoryBitMask {
        case RainDropCategory:
            cat.hitByRain()
            hud.resetPoints()
        case WorldFrameCategory:
            spawnCat()
        default : break
//            print("Something hit the cat")
        }
    }
    
    func handleFoodHit(contact: SKPhysicsContact) {
        var otherBody : SKPhysicsBody
        var foodBody : SKPhysicsBody
        
        if(contact.bodyA.categoryBitMask == FoodCategory) {
            otherBody = contact.bodyB
            foodBody = contact.bodyA
        } else {
            otherBody = contact.bodyA
            foodBody = contact.bodyB
        }
        
        switch otherBody.categoryBitMask {
        case CatCategory:
            //incrementing points
//            print("fed cat")
            hud.addPoint()
            fallthrough
        case WorldFrameCategory:
            foodBody.node?.removeFromParent()
            foodBody.node?.physicsBody = nil
            
            spawnFood()
        default: break
//            print("something else touched the food")
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
