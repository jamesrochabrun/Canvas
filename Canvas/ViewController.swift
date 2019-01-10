//
//  ViewController.swift
//  Canvas
//
//  Created by James Rochabrun on 1/9/19.
//  Copyright © 2019 James Rochabrun. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let canvas: Canvas = {
        let c = Canvas()
        c.translatesAutoresizingMaskIntoConstraints = false
        c.backgroundColor = .white
        return c
    }()
    
    let undoButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Undo", for: .normal)
        b.addTarget(self, action: #selector(handleUndo), for: .touchUpInside)
        return b
    }()
    
    let clerButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Clear", for: .normal)
        b.addTarget(self, action: #selector(handleClear), for: .touchUpInside)
        return b
    }()
    
    let firstColorButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = #colorLiteral(red: 0.9758413434, green: 0.2590503693, blue: 1, alpha: 1)
        b.addTarget(self, action: #selector(handleColorChange), for: .touchUpInside)
        return b
    }()
    
    let secondColorButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = #colorLiteral(red: 0, green: 0.9810667634, blue: 0.5736914277, alpha: 1)
        b.addTarget(self, action: #selector(handleColorChange), for: .touchUpInside)
        return b
    }()
    
    let thirdColorButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)
        b.addTarget(self, action: #selector(handleColorChange), for: .touchUpInside)
        return b
    }()
    
    let slider: UISlider = {
        let s = UISlider()
        s.minimumValue = 1
        s.maximumValue = 10
        s.addTarget(self, action: #selector(sliderDidChangeValue), for: .valueChanged)
        return s
    }()
    
    // NEW!
    override func loadView() {
        self.view = canvas
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpLayout()
    }
    
    fileprivate func setUpLayout() {
        
        let colorsStackView = UIStackView(arrangedSubviews: [firstColorButton,
                                                             secondColorButton,
                                                             thirdColorButton])
        colorsStackView.distribution = .fillEqually
        let sV = UIStackView(arrangedSubviews: [undoButton,
                                                colorsStackView,
                                                clerButton,
                                                slider])
        
        sV.translatesAutoresizingMaskIntoConstraints = false
        sV.spacing = 8
        sV.distribution = .fillEqually
        view.addSubview(sV)
        sV.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        sV.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant:-24).isActive = true
        sV.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
    
    // undo and clear
    @objc func handleUndo() {
        canvas.undo()
    }
    
    @objc func handleClear() {
        canvas.clear()
    }
    
    // change colors
    @objc func handleColorChange(_ button: UIButton) {
        canvas.setStrokeColor(button.backgroundColor ?? #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))
    }
    
    @objc func sliderDidChangeValue(_ slider: UISlider) {
        canvas.setStrokeWidth(CGFloat(slider.value))
    }
}


