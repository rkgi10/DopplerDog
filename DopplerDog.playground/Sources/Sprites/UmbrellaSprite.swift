//
//  UmbrellaSprite.swift
//  DopplerDog
//
//  Created by Rohit Gurnani on 02/04/17.
//  Copyright © 2017 Rohit Gurnani. All rights reserved.
//

import Foundation
import SpriteKit

public class UmbrellaSprite : SKSpriteNode {
    
    private var destination : CGPoint!
    private let easing : CGFloat = 0.1
    private var startingPosition : CGPoint?

    
    public static func newInstance()-> UmbrellaSprite {
        let umbrella = UmbrellaSprite(imageNamed: "umbrella2")
        
        //adding a path for creating a physics body around that path
        let path = NSBezierPath()
        path.move(to: CGPoint())
        path.line(to: CGPoint(x: -umbrella.size.width / 2 - 30, y: 0))
        path.line(to: CGPoint(x: 0, y: umbrella.size.height / 2))
        path.line(to: CGPoint(x: umbrella.size.width / 2 + 30, y: 0))
        
        umbrella.physicsBody = SKPhysicsBody(polygonFrom: path.cgPath)
        umbrella.physicsBody?.isDynamic = false
        umbrella.physicsBody?.categoryBitMask = UmbrellaCategory
        umbrella.physicsBody?.contactTestBitMask = RainDropCategory
        umbrella.physicsBody?.restitution = 0.9
        return umbrella
    }
    
    public func updatePosition(point : CGPoint) {
        position = point
        destination = point
        if let startpoint = startingPosition {
            position.x = point.x
            position.y = (startpoint.y)
            destination.x = point.x
            destination.y = (startpoint.y)
        }
        else{
            startingPosition = point
            destination = point
            position = point
        }
    }
    
    public func setDestination(destination : CGPoint) {
        if let startpoint = startingPosition {
            self.destination.x = destination.x
            self.destination.y = startpoint.y
        }
        else
        {
            self.destination = destination
        }

    }
    
    public func getCurrentDestination()->CGPoint
    {
        return self.destination
    }
    
    public func getCurrentPosition()->CGPoint
    {
        return self.position
    }
    
    public func update(deltaTime : TimeInterval) {
//        let distance = sqrt(pow((destination.x - position.x), 2) + pow((destination.y - position.y), 2))
        let distance = sqrt(pow((destination.x - position.x), 2))
        if(distance > 1) {
            let directionX = (destination.x - position.x)
//            let directionY = (destination.y - position.y)
            
            position.x += directionX * easing
//            position.y += directionY * easing
        } else {
            position.x = destination.x;
            position.y = (self.startingPosition?.y)!
        }
    }
}

extension NSBezierPath {
    
    public var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveToBezierPathElement:
                path.move(to: points[0])
            case .lineToBezierPathElement:
                path.addLine(to: points[0])
            case .curveToBezierPathElement:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePathBezierPathElement:
                path.closeSubpath()
            }
        }
        
        return path
    }
}
