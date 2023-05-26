//
//  ViewController.swift
//  IPACatcher
//
//  Created by Even on 2019/11/09.
//  Copyright © 2019 Even_cheng. All rights reserved.
//

import Cocoa
import WebKit

class MainView: NSView {
    
    let mktempPath = "/usr/bin/mktemp"
    
    private var currentWebUrls: [String] = [""]
    private var currentWebUrlLoadIndex: Int = -1

    //MARK: IBOutlets
    @IBOutlet weak var statusLabel: NSTextField?
    @IBOutlet weak var applinkLabel: NSTextField?
    @IBOutlet weak var reloadButton: NSButton?
    @IBOutlet weak var webView: WKWebView?
    @IBOutlet weak var provisionButton: NSButton?
    @IBOutlet weak var deleteButton: NSButton?

    private var tmpFolderPath: String = ""
    
    private lazy var session:URLSession = {
        //只执行一次
        let config = URLSessionConfiguration.default
        let currentSession = URLSession(configuration: config, delegate: self,
                                        delegateQueue: nil)
        return currentSession

    }()
    
    //MARK: Functions
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        if #available(OSX 10.13, *) {
            registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.URL])
        } else {
            // Fallback on earlier versions
        }
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if #available(OSX 10.13, *) {
            registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.URL])
        } else {
            // Fallback on earlier versions
        }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.wantsLayer = true
        self.layer!.backgroundColor = NSColor(red:0.28, green:0.28, blue:0.28, alpha:1.00).cgColor
        
        applinkLabel?.wantsLayer = true
        applinkLabel?.layer!.backgroundColor = NSColor(red:0.4, green:0.4, blue:0.4, alpha:1.00).cgColor
        applinkLabel?.layer!.cornerRadius = 10
        applinkLabel?.layer!.borderColor = NSColor(red:0.28, green:0.59, blue:1, alpha:0.35).cgColor
        applinkLabel?.layer!.borderWidth = 2
        
        statusLabel?.wantsLayer = true
        statusLabel?.layer!.backgroundColor = NSColor(red:0, green:0, blue:0, alpha:0.5).cgColor
    }
    
    func setStatus(_ status: String){
        Log.write(status)
        if (!Thread.isMainThread){
            DispatchQueue.main.sync{
                setStatus(status)
            }
        }
        else{
            statusLabel?.stringValue = status
        }
    }
    
    //MARK: Drag / Drop
    var fileTypes: [String] = ["txt"]
    var fileTypeIsOk = false
    
    func fileDropped(_ filename: String){
        switch(filename.pathExtension.lowercased()){
        case "txt":
            self.applinkLabel?.stringValue = filename
            break
            
        default: break
            
        }
    }
    
    func urlDropped(_ url: NSURL){
        if let urlString = url.absoluteString {
            self.applinkLabel?.stringValue = urlString
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if checkExtension(sender) == true {
            self.fileTypeIsOk = true
            return .copy
        } else {
            self.fileTypeIsOk = false
            return NSDragOperation()
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if self.fileTypeIsOk {
            return .copy
        } else {
            return NSDragOperation()
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let board = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray {
            if let filePath = board[0] as? String {
                
                fileDropped(filePath)
                return true
            }
        }
        if let types = pasteboard.types {
            if #available(OSX 10.13, *) {
                if types.contains(NSPasteboard.PasteboardType.URL) {
                    if let url = NSURL(from: pasteboard) {
                        urlDropped(url)
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
        return false
    }
    
    func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        if let board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
           let path = board[0] as? String {
            return self.fileTypes.contains(path.pathExtension.lowercased())
        }
        if let types = drag.draggingPasteboard.types {
            if #available(OSX 10.13, *) {
                if types.contains(NSPasteboard.PasteboardType.URL) {
                    if let url = NSURL(from: drag.draggingPasteboard),
                       let suffix = url.pathExtension {
                        return self.fileTypes.contains(suffix.lowercased())
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
        return false
    }
    
    func exportMobileProvision(_ ipaPath: URL) {
        setStatus("解析证书中:\(ipaPath.lastPathComponent)")
        
        let downloadPath = FileManager.default.urls(for: .downloadsDirectory, in: .allDomainsMask).last
        let saveFileName = ipaPath.lastPathComponent.replacingOccurrences(of: ".ipa", with: ".mobileprovision")
        let saveFileUrl = NSURL(fileURLWithPath: "\(downloadPath!.path)/\(saveFileName)")

        let fileData = ECIPAHelp.getMobileProvision(fromIpa: ipaPath, savePath: saveFileUrl as URL)
        guard fileData != nil else {
            setStatus("解析证书失败，请前往下载文件夹手动解压读取")
            self.loadNext()
            return
        }
        
        let certificates: String? = fileData!["team"] as? String;
        setStatus("解析证书成功 \(certificates ?? "")")
        
        if (certificates != nil) {
            let newFilePath = "\(downloadPath!.path)/\(certificates!).mobileprovision"
            try? FileManager.default.moveItem(atPath: saveFileUrl.path!, toPath: newFilePath)
        }
        if (self.deleteButton?.state == .on) {
            try? FileManager.default.removeItem(at: ipaPath)
        }
        
        self.loadNext()
    }
    
    func makeTempFolder(_ name: String!)->String?{
        let tempTask = Process().execute(mktempPath, workingDirectory: nil, arguments: ["-d","-t",name])
        if tempTask.status != 0 {
            return nil
        }
        print("tempPath:\(String(describing: name))")
        return tempTask.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    func cleanup(_ tempFolder: String){
        do {
            Log.write("Deleting: \(tempFolder)")
            try FileManager.default.removeItem(atPath: tempFolder)
        } catch let error as NSError {
            Log.write(error.localizedDescription)
        }
    }
    
    @IBAction func reloadAction(_ sender: Any) {
        
        self.currentWebUrlLoadIndex = -1
        let urlString = applinkLabel?.stringValue
        if urlString == nil || urlString!.count == 0 {
            setStatus("请指定解析地址")
            return
        }
        // 批量
        if (urlString!.hasSuffix(".txt")) {

            do {
                let fileContent = try String.init(contentsOfFile: urlString!)
                let webUrls: [String] = fileContent.components(separatedBy: "\n").filter { str in
                    let res = str.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
                    return res.count > 0
                }
                self.currentWebUrls = webUrls
                self.loadNext()

            } catch let error as NSError {
                setStatus("读取文件失败")
                Log.write(error.localizedDescription)
            }
                        
        } else {
            self.currentWebUrls = [urlString!]
            self.loadNext()
        }
    }
    
    func loadNext() {
        self.currentWebUrlLoadIndex += 1
        if (self.currentWebUrls.count <= self.currentWebUrlLoadIndex) {
            self.cleanup(self.tmpFolderPath)
            setStatus("当前任务已完成, 再次点击重新开始")
            return
        }
        var currentUrl = self.currentWebUrls[self.currentWebUrlLoadIndex]
        if (currentUrl.hasSuffix("\t")) {
            currentUrl = currentUrl.replacingOccurrences(of: "\t", with: "")
        }
        if (currentUrl.hasSuffix("\r")) {
            currentUrl = currentUrl.replacingOccurrences(of: "\r", with: "")
        }
        if (currentUrl.count <= 0) {
            loadNext()
            return
        }
        
        if (self.tmpFolderPath.count > 0) {
            self.cleanup(self.tmpFolderPath)
        }
        setStatus("开始解析\(currentUrl)")
        let url = URL.init(string: currentUrl)!
        let request = URLRequest(url: url)
        webView?.load(request)
    }
}

extension MainView : WKNavigationDelegate, URLSessionDataDelegate, URLSessionDelegate, URLSessionDownloadDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        if (webView.url?.host?.contains("pgyer.") == true) {
            
            webView.evaluateJavaScript("document.getElementsByClassName('breadcrumb ').item(0).innerHTML.toString()") { (obj: Any?, error: Error?) in
                
                if (error == nil){
                    
                    var content: String = obj as! String
                    let iosValid = content.contains("适用于 iOS 设备")
                    if iosValid == false {
                        self.setStatus("下载失败: 非iOS安装包")
                        self.loadNext()
                        return
                    }
                }
                
                webView.evaluateJavaScript("document.getElementById('down_load').text") { (obj: Any?, error: Error?) in
                    if (error != nil){
                        self.setStatus("下载失败:\(String(describing: error!.localizedDescription))")
                        print(error!)
                        self.loadNext()
                       return
                    }

                    var title: String = obj as! String
                    title = title.replacingOccurrences(of: " ", with: "")
                    title = title.replacingOccurrences(of: "\n", with: "")
                    if (title == "安装") {

                        webView.evaluateJavaScript("install_loading()") { (obj: Any?, error: Error?) in
                            if (error != nil){

                                self.setStatus("下载失败:\(String(describing: error!.localizedDescription))")
                                print(error!)
                                self.loadNext()
                            }
                        }

                    } else {
                        self.setStatus("\(String(describing: title))")
                        self.loadNext()
                    }
                }
            }

        } else if (webView.url?.host?.contains("fir.") == true) {

            let jsStr = "document.querySelector(\"body.app > div.out-container > div.main > header > div.table-container > div.cell-container > div.app-brief > div#actions.type-ios\").style.display = \"block\";";
            webView.evaluateJavaScript(jsStr) { (obj: Any?, error: Error?) in

            }
            webView.evaluateJavaScript("FIR.install()")
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        
        setStatus("解析失败:\(String(describing: error.localizedDescription))")
        print(error)
        self.loadNext()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        
        setStatus("解析失败:\(String(describing: error.localizedDescription))")
        print(error)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let urlString = navigationAction.request.url?.absoluteString ?? ""

        if (urlString.hasPrefix("itms-services://")) {
            
            decisionHandler(.cancel)
            analysePlist(urlString);

        } else if (urlString.hasSuffix(".ipa") || urlString.hasSuffix(".zip")) {
            
            decisionHandler(.cancel)
            download(urlString)

        } else if (urlString.hasSuffix(".plist")) {
            
            decisionHandler(.cancel)
            analysePlist(urlString);
            
        } else {
            
//            setStatus("解析\(urlString)")
            decisionHandler(.allow)
        }
    }
    
    func download(_ downUrl: String!) {
            
        setStatus("解析完成，等待下载")
        let request = URLRequest(url: URL.init(string: downUrl)!, cachePolicy: .useProtocolCachePolicy)
        let downloadTask = session.downloadTask(with: request)
        downloadTask.resume()
    }
    
    func analysePlist(_ p_url: String!) {
        
        setStatus("正在解析")
        
        var url = p_url.urlDecoded();
        if (url.hasPrefix("itms-services://")) {
            url = url.components(separatedBy: "url=").last!
        }
        var request: URLRequest = URLRequest.init(url: URL.init(string: url)!)
        request.setValue("com.apple.appstored/1.0 iOS/16.1.1 model/iPhone12,1 hwp/t8030 build/20B101 (6; dt:203) AMS/1", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { (data:Data?, response:URLResponse?, error:Error?) in
            guard data != nil else {
                self.setStatus(error?.localizedDescription ?? "解析失败")
                self.loadNext()
                return
            }
            let str = String.init(data: data!, encoding: .utf8)
            self.tmpFolderPath = self.makeTempFolder("temp") ?? ""
            let dateStr: NSNumber = NSNumber(value: NSDate().timeIntervalSince1970)
            let plistUrl = NSURL(fileURLWithPath: self.tmpFolderPath + "/\(dateStr.stringValue).plist")
            do {
                try str?.write(to: plistUrl as URL, atomically: true, encoding: .utf8)
                let dic = NSDictionary(contentsOf: plistUrl as URL)
                let items: Array = dic!["items"] as! Array<Any>
                let assetDic: Dictionary = items.first as! Dictionary<String, Any>
                let assets: [[String:Any]] = assetDic["assets"] as! [[String:Any]]
                for ass in assets {
                    if (ass["kind"] as! String == "software-package") {
                        let ipa_url: String = ass["url"] as? String ?? ""
                        self.download(ipa_url)
                        break
                    }
                }
                
            } catch let error {
                self.loadNext()
                self.setStatus(error.localizedDescription)
            }
            
        }.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let downloadError = downloadTask.error as NSError?
        if downloadError == nil {
            
            let downloadPath = FileManager.default.urls(for: .downloadsDirectory, in: .allDomainsMask).last
            let originalName: String = downloadTask.currentRequest?.url?.absoluteString.lastPathComponent ?? ""
            var fileNameString: String = originalName;
            if (originalName.hasSuffix(".ipa") == true) {
                fileNameString = originalName.components(separatedBy: "filename").last!.urlDecoded()
            } else {
                fileNameString = originalName.components(separatedBy: "=").last!.urlDecoded() + ".ipa"
            }
            if (fileNameString.hasPrefix("=")) {
                let startIndex = fileNameString.index(fileNameString.startIndex, offsetBy: 1)
                fileNameString = String(fileNameString[startIndex...])
            }
            let movePath = downloadPath!.absoluteString + fileNameString
            do {
                let moveUrl = URL(string: movePath.urlEncoded())!
                if (FileManager.default.fileExists(atPath: moveUrl.path)) {
                    try FileManager.default.removeItem(at: moveUrl)
                }
                try FileManager.default.moveItem(at: location, to: moveUrl)
                DispatchQueue.main.sync{
                    setStatus("下载完成:\(movePath)")
                    if (self.provisionButton?.state == .on) {
                        self.exportMobileProvision(moveUrl)
                    } else {
                        self.loadNext()
                    }
                }
            } catch let error {
                DispatchQueue.main.sync{
                    self.setStatus(error.localizedDescription)
                    self.loadNext()
                }
            }
            
        } else {
            DispatchQueue.main.sync{
                setStatus("下载失败:\(String(describing: downloadError?.localizedDescription))")
                self.loadNext()
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        let percentDownloaded = (Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100
        let percent = String(format: "%.2f%%", percentDownloaded)
        let size = String(format: "共%.fM", Double(totalBytesExpectedToWrite)/1000000)
        DispatchQueue.main.sync{
            setStatus("[\(self.currentWebUrlLoadIndex+1)/\(self.currentWebUrls.count)] 下载中: \(size)  \(percent)")
        }
    }
}

extension String {
         
    //将原始的url编码为合法的url
    func urlEncoded() -> String {
        let encodeUrlString = self.addingPercentEncoding(withAllowedCharacters:
                .urlQueryAllowed)
        return encodeUrlString ?? ""
    }
    
    //将编码后的url转换回原始的url
    func urlDecoded() -> String {
        return self.removingPercentEncoding ?? ""
    }
}

// NSTextField 支持快捷键
extension NSTextField {
    open override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.isDisjoint(with: .command) {
            return super.performKeyEquivalent(with: event)
        }
        
        switch event.charactersIgnoringModifiers {
        case "a":
            return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: self.window?.firstResponder, from: self)
        case "c":
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: self.window?.firstResponder, from: self)
        case "v":
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: self.window?.firstResponder, from: self)
        case "x":
            return NSApp.sendAction(#selector(NSText.cut(_:)), to: self.window?.firstResponder, from: self)
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
