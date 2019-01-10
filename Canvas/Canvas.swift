//
//  Canvas.swift
//  Canvas
//
//  Created by James Rochabrun on 1/9/19.
//  Copyright © 2019 James Rochabrun. All rights reserved.
//

import UIKit

class Canvas: UIView {
    
    fileprivate var lines: [Line] = []
    fileprivate var strokeColor = UIColor.black
    fileprivate var strokeWidth: CGFloat = 1.0

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        lines.forEach { line in
            context.setStrokeColor(line.color.cgColor)
            context.setLineWidth(line.width)
            context.setLineCap(.round)
            for (i, p) in line.points.enumerated() {
                i == 0 ? context.move(to: p) : context.addLine(to: p)
            }
            context.strokePath()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lines.append(Line.init(color: strokeColor, width: strokeWidth, points: []))
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: nil) else { return }
        guard var lastLine = lines.popLast() else { return }
        lastLine.points.append(point)
        lines.append(lastLine)
        setNeedsDisplay()
    }
    
    // public function
    func undo() {
        _ = lines.popLast()
        setNeedsDisplay()
    }
    
    func clear() {
        lines.removeAll()
        setNeedsDisplay()
    }
    
    func setStrokeColor(_ color: UIColor) {
        self.strokeColor = color
    }
    
    func setStrokeWidth(_ value: CGFloat) {
        self.strokeWidth = value
    }
}
