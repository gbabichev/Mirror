//
//  Helper.swift
//  LoginItem-Helper
//
//  Created by George Babichev on 7/29/25.
//

import Cocoa // Import macOS UI framework

class LoginItemHelperApp: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainAppBundleID = "com.georgebabichev.Mirror" // The bundle ID of the main app
        
        // Check if the main app is NOT running AND we can get its URL; if either fails, quit the helper immediately.
        guard !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == mainAppBundleID }),
              let mainAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppBundleID)
        else {
            NSApp.terminate(nil) // Quit helper if main app is running or can’t be found
            return
        }
        
        // Launch the main app.
        // When the launch completes (success or fail), the completion handler will be called, and we quit the helper.
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: NSWorkspace.OpenConfiguration()) { _,_ in
            NSApp.terminate(nil) // Quit helper after attempting to launch main app
        }
        
        // Failsafe: In rare cases, the completion handler could be delayed or never called (system bugs, odd launch states).
        // This async block makes sure the helper will quit after 1 second no matter what,
        // preventing it from hanging around in memory if something goes sideways.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.terminate(nil) // Force-quit helper just in case
        }
    }
}
