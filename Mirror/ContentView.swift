//
//  ContentView.swift
//  Mirror
//
//  Manages the UI
//
//  Created by George Babichev on 7/27/25.
//

import SwiftUI
import AVFoundation

// MARK: - CameraPreviewView (NSViewRepresentable)
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    @Binding var isMirrored: Bool

    // NSView subclass that hosts the AVCaptureVideoPreviewLayer
    class VideoPreviewView: NSView {
        private var previewLayer: AVCaptureVideoPreviewLayer?

        // Sets up the preview layer using the provided AVCaptureSession
        func setupLayer(with session: AVCaptureSession) {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = bounds
            wantsLayer = true
            layer = CALayer()
            if let previewLayer = previewLayer {
                layer?.addSublayer(previewLayer)
            }
        }

        // Updates the preview layer's frame when the view's layout changes
        override func layout() {
            super.layout()
            previewLayer?.frame = bounds
        }

        // Mirrors the video preview horizontally based on the isMirrored flag
        func updateMirror(_ mirrored: Bool) {
            guard let previewLayer = previewLayer else { return }
            previewLayer.setAffineTransform(mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
            previewLayer.setNeedsDisplay()
            previewLayer.setNeedsLayout()
            previewLayer.layoutIfNeeded()
        }
    }

    // Creates and configures the NSView that hosts the camera preview
    func makeNSView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.setupLayer(with: session)
        view.updateMirror(isMirrored)
        return view
    }

    // Updates the mirror setting whenever the SwiftUI binding changes
    func updateNSView(_ nsView: VideoPreviewView, context: Context) {
        guard let previewLayer = nsView.layer?.sublayers?.compactMap({ $0 as? AVCaptureVideoPreviewLayer }).first else {
            nsView.setupLayer(with: session)
            nsView.updateMirror(isMirrored)
            return
        }

        if previewLayer.session !== session {
            // Stop the old session before switching
            previewLayer.session?.stopRunning()
            previewLayer.session = session
            
            // Small delay to ensure session is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nsView.updateMirror(isMirrored)
            }
        } else {
            nsView.updateMirror(isMirrored)
        }
    }
}

// MARK: - ContentView (Main App UI)
struct ContentView: View {
    @ObservedObject var cameraViewModel: CameraViewModel

    // Main SwiftUI View displaying either the camera preview or permission prompt
    var body: some View {
        // Show live camera feed if access is granted
        #if DEMO
        Image("Dude")
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              //.scaleEffect(x: viewModel.isFlipped ? -1 : 1, y: 1)
              .overlay(alignment: .bottomTrailing) {
                  Button(action: {
                      cameraViewModel.isMirrored.toggle()
                  }) {
                      Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                          .foregroundColor(.white)
                          .font(.system(size: 24))
                          .opacity(0.8)
                          .padding(12) // Space inside the circle
                          .background(Circle().fill(Color.black.opacity(0.3)))
                  }
                  .buttonStyle(.plain)
                  .padding(6)
                  .help("Flip Camera Horizontally")
              }
        #else
        if cameraViewModel.hasCameraAccess {
            ZStack {
//                CameraPreviewView(session: cameraViewModel.session, isMirrored: $cameraViewModel.isMirrored)
//                    .id(cameraViewModel.session)
//                    .frame(width: 500, height: 500)
                VStack {
//                    if !cameraViewModel.cameraDebugStatus.isEmpty {
//                        Text(cameraViewModel.cameraDebugStatus)
//                            .font(.caption2)
//                            .foregroundColor(.red)
//                            .padding(.top, 15)
//                    }
                    CameraPreviewView(session: cameraViewModel.session, isMirrored: $cameraViewModel.isMirrored)
                        .frame(width: 500, height: 500)
                }
                
                if cameraViewModel.session.inputs.isEmpty {
                    Text("No Cameras Connected")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }

                // existing overlay button...
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .opacity(0.8)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .help("Close Preview")

                        Spacer()

                        Button(action: {
                            cameraViewModel.isMirrored.toggle()
                        }) {
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .opacity(0.8)
                                .padding(12) // Space inside the circle
                                .background(Circle().fill(Color.black.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .help("Flip Camera Horizontally")
                    }
                }
            }
        // Otherwise, show a message and button to open System Settings
        } else {
            VStack(spacing: 12) {
                Text("Camera access is required.\nPlease enable it in System Settings > Privacy & Security.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer().frame(height: 12)
                
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .padding(.bottom)
            }
            .frame(width: 500, height: 500)
        }
        #endif
    }
    
}
