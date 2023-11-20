//
//  File.swift
//  
//
//  Created by Sam on 14/11/2023.
//

#if os(iOS)
import Foundation
import UIKit
import Metal
import MetalKit
import CoreImage

public class DotLottieViewUIKit: UIViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the background color of the view
        view.backgroundColor = UIColor.white
        
        // Create a label
        let label = UILabel()
        label.text = "Hello, UIKit!"
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.font = UIFont.systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the label to the view
        view.addSubview(label)
        
        // Set constraints for the label (center it in the view)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// Usage: Creating and presenting the view controller
//let viewController = MyViewController()
//// Present the view controller in a navigation controller
//let navigationController = UINavigationController(rootViewController: viewController)
//navigationController.modalPresentationStyle = .fullScreen
//
//// Present the navigation controller in the main window
//if let window = UIApplication.shared.windows.first {
//    window.rootViewController = navigationController
//    window.makeKeyAndVisible()
//}
#endif
