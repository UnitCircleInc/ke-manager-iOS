//
//  ScanViewController.swift
//  Konnex
//
//  Created by Sean Simmons on 2020-03-23.
//  Copyright © 2020 Unit Circle Inc. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

struct Unit: Codable {
    var corp: String
    var site: String
    var unit: String
}

struct Lock: Codable {
    var lock: String
}

class ScanViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var qrFrame: UIView!
    @IBOutlet weak var topbar: UIView!
    @IBOutlet weak var bottombar: UIView!
    @IBOutlet weak var unitLabel: UILabel!
    @IBOutlet weak var lockLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    
    var unit: Unit?
    var lock: Lock?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearPressed(self)

        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        view.bringSubviewToFront(topbar)
        view.bringSubviewToFront(bottombar)
        
        qrFrame = UIView()
        qrFrame.layer.borderColor = UIColor.green.cgColor
        qrFrame.layer.borderWidth = 2
        view.addSubview(qrFrame)
        view.bringSubviewToFront(qrFrame)

        captureSession.startRunning()
    }

    @IBAction func CancelPressed(_ sender: Any) {
        captureSession.stopRunning()
        dismiss(animated: true)
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
        
            
            let decoder = JSONDecoder()
            if let new_unit = try? decoder.decode(Unit.self, from: stringValue.data(using: .utf8)!) {
                if unit == nil {
                    unit = new_unit
                    unitLabel.text = unit!.unit
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                }
            } else if let new_lock = try? decoder.decode(Lock.self, from: stringValue.data(using: .utf8)!){
                if lock == nil {
                    lock = new_lock
                    lockLabel.text = lock!.lock
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                }
            }
            else {
                return
            }
            addButton.isEnabled = unit != nil && lock != nil
            clearButton.isEnabled = unit != nil || lock != nil
        }
    }
    
    @IBAction func addPressed(_ sender: Any) {
        print("addButton pressed")
        guard let lock = lock else {return}
        guard let unit = unit else {return}
        
        addButton.isEnabled = false
        clearButton.isEnabled = false
        
        // TODO Send registration to Konnex Server
        print("Adding lock: \(lock.lock) to unit: \(unit.unit)")
        DispatchQueue.main.async {
          let appDelegate = UIApplication.shared.delegate as! AppDelegate
          appDelegate.assignLockToUnit(unit, lock: lock)
        }
        // Only show alert after confirmed - or display error if unable to add
        // Don't clear if error to allow someone to try adding again - incase of temp connectivity issues
        showAlertMsg(title: "Adding", message: "Lock: \(lock.lock)\nUnit: \(unit.unit)")
        clearPressed(self)
    }
    
    @IBAction func clearPressed(_ sender: Any) {
        print("clearButton pressed")
        unit = nil
        lock = nil
        unitLabel.text = ""
        lockLabel.text = ""
        addButton.isEnabled = false
        clearButton.isEnabled = false
    }
    
    func showAlertMsg(title: String, message: String){
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true, completion: nil)

        let time = DispatchTime.now() + .seconds(3)
        
        DispatchQueue.main.asyncAfter(deadline: time) {
            alertController.dismiss(animated: true)
        }

    }
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
