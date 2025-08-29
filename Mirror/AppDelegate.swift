//
//  AppDelegate.swift
//  Mirror.app
//
//  Manages the macOS app lifecycle, menu bar icon, popover behavior, and right-click menu
//
//  Created by George Babichev on 7/27/25.
//

// To Archive in "demo" mode (no webcam view, just a pic of Dude).
// Xcode -> Project (left bar, top item) -> Target (in left bar) -> Build Settings
// -> search for "Swift Compiler - Custom Flags" -> add "DEMO" under "Release".
// NOTE - This only works for "Archive", not debug or run.
// Set the demo flag, archive the app, distribute & test.

// MARK: - AppDelegate
// Handles menu bar UI, popover lifecycle, right-click camera switcher, and session control

// tccutil reset Camera com.georgebabichev.Mirror

import AppKit
import SwiftUI
import ServiceManagement
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSMenuDelegate {
    // Bundle ID of Helper App
    private let loginHelperIdentifier = "com.georgebabichev.MirrorHelper"
    
    // Status bar item that displays the app icon in the menu bar
    var statusItem: NSStatusItem!
    // Popover that displays the main SwiftUI camera view
    var popover: NSPopover!
    var viewModel = CameraViewModel()
    // Global click monitor to detect clicks outside the popover
    var globalClickMonitor: Any?

    // Sets up the status bar item, popover behavior, and right-click menu handler
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Mirror")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }

        // Create the popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 500, height: 500)

        // Add local event monitor for right click on status bar button (more reliable local coordinates)
        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseUp]) { [weak self] event in
            guard let self = self, let button = self.statusItem.button else { return event }

            let locationInButton = button.convert(event.locationInWindow, from: nil)
            if button.bounds.contains(locationInButton) {
                self.handleRightClick()
                return nil
            }

            return event
        }
    }
    // Displays a context menu for selecting a camera device or quitting the app
    @objc func handleRightClick() {
        let menu = NSMenu()

        // Refresh video devices on each right click so we're not showing stale devices.
        viewModel.refreshVideoDevices()
        
        // Shows a list of available cameras.
        for (index, name) in viewModel.deviceNames.enumerated() {
            let item = NSMenuItem(title: name, action: #selector(selectCamera(_:)), keyEquivalent: "")
            item.representedObject = index
            item.state = index == viewModel.currentDeviceIndex ? .on : .off
            item.target = self

            if viewModel.videoDevices.indices.contains(index) {
                let device = viewModel.videoDevices[index]
                print("📷 \(device.localizedName) — connected: \(device.isConnected), suspended: \(device.isSuspended)")
                
                if device.isUsable {
                    item.action = #selector(selectCamera(_:))
                    item.target = self
                    item.isEnabled = true
                } else {
                    item.action = nil
                    item.target = nil
                    item.isEnabled = false
                }
            }

            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Start at Login toggle
        let launchAtLoginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        
        // Shows the "About" menu item.
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        //menu.addItem(NSMenuItem.separator())
        // Shows the "Quit" menu item.
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: statusItem.button!)
    }

    @objc func showAboutWindow() {
        let aboutView = AboutView() // Your SwiftUI view
        let hostingController = NSHostingController(rootView: aboutView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About"
        window.setContentSize(NSSize(width: 400, height: 400))
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Terminates the app
    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // Handles left-click on the status bar item to show the popover
    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        showPopover()
    }

    // Shows the SwiftUI camera preview inside the popover and starts camera session
    @objc func showPopover() {
        guard let button = statusItem.button else { return }

        let contentView = ContentView(cameraViewModel: viewModel)
        let hosting = NSHostingController(rootView: contentView)
        popover.contentViewController = hosting

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Add global click monitor to close popover on outside click
//        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
//            self?.popover.performClose(nil)
//        }
        viewModel.checkCameraAuthorization { granted in
            if granted {
                self.viewModel.startSession()
            } else {
                // Optionally show an alert or log a message
                print("Camera access denied.")
            }
        }
    }

    // Stops the session and removes monitors when the popover is dismissed
    func popoverDidClose(_ notification: Notification) {
        viewModel.stopSession()
        popover.contentViewController = nil
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    // Switches to the selected camera when a menu item is clicked
    @objc func selectCamera(_ sender: NSMenuItem) {
        guard sender.isEnabled else {
            print("⛔️ Ignored disabled menu item: \(sender.title)")
            return
        }
        if let index = sender.representedObject as? Int {
            viewModel.currentDeviceIndex = index
            viewModel.switchToCamera(at: index)
        }
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        let loginService = SMAppService.loginItem(identifier: loginHelperIdentifier)
        do {
            if enabled {
                try loginService.register()
            } else {
                try loginService.unregister()
            }
        } catch {
            showErrorAlert(message: "Failed to update Login Item.", info: error.localizedDescription)
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        let loginService = SMAppService.loginItem(identifier: loginHelperIdentifier)
        return loginService.status == .enabled
    }

    private func showErrorAlert(message: String, info: String? = nil) {
        let alert = NSAlert()
        alert.messageText = message
        if let info = info {
            alert.informativeText = info
        }
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc func toggleLoginItem(_ sender: NSMenuItem) {
        let currentlyEnabled = isLaunchAtLoginEnabled()
        toggleLaunchAtLogin(!currentlyEnabled)
    }
}

// MARK: - AVCaptureDevice Extension

extension AVCaptureDevice {
    var isUsable: Bool {
        if #available(macOS 14, *) {
            return isConnected && !isSuspended
        } else {
            return isConnected
        }
    }
}

// MARK: - MirrorApp Entry Point
// Connects SwiftUI app lifecycle to AppDelegate
@main
struct MirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
