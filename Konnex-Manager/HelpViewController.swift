//
//  HelpViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2021-08-26.
//  Copyright © 2021 Unit Circle Inc. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController, UIScrollViewDelegate {
    var slides:[HelpSlide] = []
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var doneButton: UIButton!
    
 
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        slides = createSlides()
        setupSlideScrollView(slides: slides)
        pageControl.numberOfPages = slides.count
        pageControl.currentPage = 0
        view.bringSubviewToFront(pageControl)
    }
    
    @IBAction func doneButtonPressed(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    @IBAction func pageChanged(_ sender: Any) {
        var frame = scrollView.frame
        frame.origin.x = frame.size.width * CGFloat(pageControl.currentPage)
        frame.origin.y = 0
        scrollView.scrollRectToVisible(frame, animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = round(scrollView.contentOffset.x/view.frame.width)
        pageControl.currentPage = Int(pageIndex)
            
        let maximumHorizontalOffset: CGFloat = scrollView.contentSize.width - scrollView.frame.width
        let currentHorizontalOffset: CGFloat = scrollView.contentOffset.x
        
         let maximumVerticalOffset: CGFloat = scrollView.contentSize.height - scrollView.frame.height
        let currentVerticalOffset: CGFloat = scrollView.contentOffset.y
        
        let percentageHorizontalOffset: CGFloat = currentHorizontalOffset / maximumHorizontalOffset
        let percentageVerticalOffset: CGFloat = currentVerticalOffset / maximumVerticalOffset

        let percentOffset: CGPoint = CGPoint(x: percentageHorizontalOffset, y: percentageVerticalOffset)
        
        if(percentOffset.x > 0 && percentOffset.x <= 0.5) {

            slides[0].imageView.transform = CGAffineTransform(scaleX: (0.5-percentOffset.x)/0.5, y: (0.5-percentOffset.x)/0.5)
            slides[1].imageView.transform = CGAffineTransform(scaleX: percentOffset.x/0.5, y: percentOffset.x/0.5)

        } else if(percentOffset.x > 0.5 && percentOffset.x <= 1) {
            slides[1].imageView.transform = CGAffineTransform(scaleX: (1-percentOffset.x)/0.5, y: (1-percentOffset.x)/0.5)
            slides[2].imageView.transform = CGAffineTransform(scaleX: (percentOffset.x-0.5)/0.5, y: (percentOffset.x-0.5)/0.5)
        }

//        if(percentOffset.x > 0 && percentOffset.x <= 0.25) {
//
//            slides[0].imageView.transform = CGAffineTransform(scaleX: (0.25-percentOffset.x)/0.25, y: (0.25-percentOffset.x)/0.25)
//            slides[1].imageView.transform = CGAffineTransform(scaleX: percentOffset.x/0.25, y: percentOffset.x/0.25)
//
//        } else if(percentOffset.x > 0.25 && percentOffset.x <= 0.50) {
//            slides[1].imageView.transform = CGAffineTransform(scaleX: (0.50-percentOffset.x)/0.25, y: (0.50-percentOffset.x)/0.25)
//            slides[2].imageView.transform = CGAffineTransform(scaleX: percentOffset.x/0.50, y: percentOffset.x/0.50)
//
//        } else if(percentOffset.x > 0.50 && percentOffset.x <= 0.75) {
//            slides[2].imageView.transform = CGAffineTransform(scaleX: (0.75-percentOffset.x)/0.25, y: (0.75-percentOffset.x)/0.25)
//            slides[3].imageView.transform = CGAffineTransform(scaleX: percentOffset.x/0.75, y: percentOffset.x/0.75)
//
//        } else if(percentOffset.x > 0.75 && percentOffset.x <= 1) {
//            slides[3].imageView.transform = CGAffineTransform(scaleX: (1-percentOffset.x)/0.25, y: (1-percentOffset.x)/0.25)
//            slides[4].imageView.transform = CGAffineTransform(scaleX: percentOffset.x, y: percentOffset.x)
//        }
        
        scrollView.contentOffset.y = 0
    }
    
    func setupSlideScrollView(slides : [HelpSlide]) {
        scrollView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        scrollView.contentSize = CGSize(width: view.frame.width * CGFloat(slides.count), height: view.frame.height)
        scrollView.isPagingEnabled = true
        
        for i in 0 ..< slides.count {
            slides[i].frame = CGRect(x: view.frame.width * CGFloat(i), y: 0, width: view.frame.width, height: view.frame.height)
            scrollView.addSubview(slides[i])
        }
    }
    
    func createSlides() -> [HelpSlide] {
        let slide1:HelpSlide = Bundle.main.loadNibNamed("HelpSlide", owner: self, options: nil)?.first as! HelpSlide
        slide1.imageView.image = UIImage(named: "help.1")
        slide1.labelTitle.text = "Installation Process"
        slide1.labelDescription.text = "Place corresponding QR codes on the unit doors"
        
        let slide2:HelpSlide = Bundle.main.loadNibNamed("HelpSlide", owner: self, options: nil)?.first as! HelpSlide
        slide2.imageView.image = UIImage(named: "help.2")
        slide2.labelTitle.text = "Installation Process"
        slide2.labelDescription.text = "Use the camera found in the Install Lock tab to scan the QR on the lock with the QR on the unit door"
        
        let slide3:HelpSlide = Bundle.main.loadNibNamed("HelpSlide", owner: self, options: nil)?.first as! HelpSlide
        slide3.imageView.image = UIImage(named: "help.3")
        slide3.labelTitle.text = "Installation Process"
        slide3.labelDescription.text = "Once the association is made, press the power button to unlock the lock and place on the corresponding unit hasp"
        
//        let slide4:HelpSlide = Bundle.main.loadNibNamed("HelpSlide", owner: self, options: nil)?.first as! HelpSlide
//        slide4.imageView.image = UIImage(named: "Image")
//        slide4.labelTitle.text = "A real-life bear"
//        slide4.labelDescription.text = "Did you know that Winnie the chubby little cubby was based on a real, young bear in London"
//
//
//        let slide5:HelpSlide = Bundle.main.loadNibNamed("HelpSlide", owner: self, options: nil)?.first as! HelpSlide
//        slide5.imageView.image = UIImage(named: "Image")
//        slide5.labelTitle.text = "A real-life bear"
//        slide5.labelDescription.text = "Did you know that Winnie the chubby little cubby was based on a real, young bear in London"
//
//        return [slide1, slide2, slide3, slide4, slide5]
        return [slide1, slide2, slide3]
    }
}
