//
//  CameraViewModel.swift
//  Mirror
//
//  Manages camera logic: device discovery, session start/stop, switching, flipping, and permissions
//
//  Created by George Babichev on 7/27/25.
//


// MARK: - CameraViewModel
// Manages camera logic: session management, camera switching, mirroring, and permissions

import SwiftUI
import AVFoundation
import Combine

class CameraViewModel: ObservableObject {
    // Index of the currently selected camera device
    @Published var currentDeviceIndex: Int = 0
    
    // Capture session used for camera input/output
    @Published var session = AVCaptureSession()
    
    // Indicates whether the app has permission to access the camera
    @Published var hasCameraAccess: Bool = true
    
    // Reflects whether the video feed should be horizontally mirrored
    // Saves user preference to UserDefaults
    @Published var isMirrored: Bool {
        didSet {
            UserDefaults.standard.set(isMirrored, forKey: "isMirrored")
        }
    }
    
    // List of discovered video capture devices (front/rear cameras)
    private(set) var videoDevices: [AVCaptureDevice] = []

    // Convenience accessor for device display names
    var deviceNames: [String] {
        videoDevices.map { $0.localizedName }
    }

    // Initializes state, loads mirror setting, discovers devices, sets default camera
    init() {
        self.isMirrored = UserDefaults.standard.bool(forKey: "isMirrored")
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        videoDevices = discoverySession.devices
        switchToCamera(at: 0)
    }

    // Checks current camera permission and requests it if not yet determined
    func checkCameraAuthorization(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraAccess = true
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasCameraAccess = granted
                    completion(granted)
                }
            }
        case .denied, .restricted:
            hasCameraAccess = false
            completion(false)
        @unknown default:
            hasCameraAccess = false
            completion(false)
        }
    }
    
    // Starts the AVCaptureSession
    func startSession() {
        session.startRunning()
    }

    // Stops the AVCaptureSession
    func stopSession() {
        session.stopRunning()
    }
    
    // Switches the session input to a new camera device by index
    // Removes existing inputs and adds the selected device input
    func switchToCamera(at index: Int) {
        guard index < videoDevices.count else { return }
        currentDeviceIndex = index
        let device = videoDevices[index]

        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.commitConfiguration()
        session.startRunning()
    }
}
