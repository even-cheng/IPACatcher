//
//  AppDelegate.swift
//  AppSigner
//
//  Created by Daniel Radtke on 11/2/15.
//  Copyright © 2015 Daniel Radtke. All rights reserved.
//

import Cocoa
//import LeanCloud

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    //用于保存后台下载的completionHandler
    var backgroundSessionCompletionHandler: (() -> Void)?
    func application(_ application: NSApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        self.backgroundSessionCompletionHandler = completionHandler
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("后台任务下载回来")
        DispatchQueue.main.async {
            guard let appDelegate = NSApplication.shared.delegate as? AppDelegate, let backgroundHandle = appDelegate.backgroundSessionCompletionHandler else { return }
            backgroundHandle()
        }
    }
    
    @IBOutlet weak var mainView: MainView!
    let fileManager = FileManager.default
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

    }
    

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        try? fileManager.removeItem(atPath: Log.logName)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @IBAction func nsMenuLinkClick(_ sender: NSMenuLink) {
        NSWorkspace.shared.open(URL(string: sender.url!)!)
    }
    @IBAction func viewLog(_ sender: AnyObject) {
        NSWorkspace.shared.openFile(Log.logName)
    }
    @IBAction func checkForUpdates(_ sender: NSMenuItem) {
        
    }
}

