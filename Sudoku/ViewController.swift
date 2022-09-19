//
//  ViewController.swift
//  Sudoku
//
//  Created by 이주화 on 2022/09/06.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var goPhotoView: UIButton!
    @IBOutlet weak var goPickerView: UIButton!
    
    let bounds = UIScreen.main.bounds

    override func viewDidLoad() {
        super.viewDidLoad()
        setButton()
        setTitleLabel()
        imageView.image = UIImage(named: "sudokuImage")
        // Do any additional setup after loading the view.
    }

    private func setTitleLabel() {
        self.view.addSubview(titleLabel)
        titleLabel.text = "SolDoKu"
        titleLabel.textColor = .black
        titleLabel.font = .systemFont(ofSize: 50, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.topAnchor.constraint(equalTo: self.view.topAnchor, constant: bounds.height/10).isActive = true
        titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    }

    private func setButton() {
        goPhotoView.layer.cornerRadius = 10
        goPickerView.layer.cornerRadius = 10
    }
}

