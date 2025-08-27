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
    
    @Published var cameraDebugStatus: String = ""
    
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
        observeDeviceChanges()
        refreshVideoDevices()

        if !videoDevices.isEmpty {
            switchToCamera(at: 0)
        } else {
            cameraDebugStatus = "❌ No video devices found at launch"
        }
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
        print("🟡 switchToCamera called with index \(index)")
        self.cameraDebugStatus = "🟡 Switching to camera index \(index)"
        guard index < videoDevices.count else { return }

        let device = videoDevices[index]
        let newSession = AVCaptureSession()

        guard let input = try? AVCaptureDeviceInput(device: device),
              newSession.canAddInput(input) else {
            print("Failed to add input for device: \(device.localizedName)")
            return
        }

        newSession.addInput(input)
        newSession.startRunning()

        self.currentDeviceIndex = index
        self.session = newSession // <– this triggers SwiftUI update

        print("Switched to camera: \(device.localizedName)")
        self.cameraDebugStatus = "Switched to: \(device.localizedName) — inputs: \(newSession.inputs.count)"
    }
    
    func refreshVideoDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        videoDevices = discoverySession.devices

        if videoDevices.isEmpty {
            print("❌ No video devices found")
            cameraDebugStatus = "❌ No cameras detected"
            session = AVCaptureSession() // clear session to trigger view update
        } else {
            print("✅ Found devices: \(videoDevices.map { $0.localizedName }.joined(separator: ", "))")
            cameraDebugStatus = "✅ Found: \(videoDevices.first?.localizedName ?? "Unknown")"
        }
    }
    
    private func observeDeviceChanges() {
        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.refreshVideoDevices()
                if !self.videoDevices.isEmpty {
                    self.switchToCamera(at: 0)
                } else {
                    self.cameraDebugStatus = "❌ No devices after connect"
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.refreshVideoDevices()

            // Always fall back to the first working camera in the refreshed list
            if let fallbackDevice = self.videoDevices.first {
                print("DISCONNECTED or invalid device. Switching to: \(fallbackDevice.localizedName)")
                self.switchToCamera(at: 0)
            } else {
                print("No available cameras to switch to.")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
