//
//  ChatViewController.swift
//  RemoteAssistance
//
//  Created by Yulius Tjahjadi on 12/12/19.
//  Copyright © 2019 FXPAL. All rights reserved.
//

import UIKit
import WebKit

class ChatViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        let url = "\(store.ace.state.serverUrl)/chat"
        let chatUrl = URL(string:url)
        let request = URLRequest(url: chatUrl!)
        webView.configuration.userContentController.add(self, name: "launchRA")
        webView.configuration.userContentController.add(self, name: "launchQRScanner")
        webView.configuration.userContentController.add(self, name: "launchOCRScanner")
        webView.configuration.userContentController.add(self, name: "launchARScene")
        
        // Next one to add
        //webView.configuration.userContentController.add(self, name: "launchARVideo")

        webView.load(request)
        webView.navigationDelegate = self
        
        //let c = uicolorFromHex(rgbValue: 0x004c83)
        let c = UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0)
        navigationController?.navigationBar.tintColor = c
        navigationController?.navigationBar.barTintColor = c
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func uicolorFromHex(rgbValue:UInt32)->UIColor{
        let red = CGFloat((rgbValue & 0xFF0000) >> 16)/256.0
        let green = CGFloat((rgbValue & 0xFF00) >> 8)/256.0
        let blue = CGFloat(rgbValue & 0xFF)/256.0

        return UIColor(red:red, green:green, blue:blue, alpha:1.0)
    }
    
    func generateRandomId(_ length:Int = 9) -> String {
        let letters = "0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }

    func launchRA(dict: NSDictionary) {
        var roomId = "fxpal"
        
        if let archive = dict["archive"] as? [String:Any] {
            // save conversation archive to user defaults
            UserDefaults.standard.set(archive, forKey: "conversation_archive")

            // create room name based on printer
            if let printerName = archive["printerName"] as? String {
                roomId = "\(printerName.replacingOccurrences(of:" ", with: "-"))-\(generateRandomId())"
            }
        }
        
        // Launch remote assist view controller with room uuid: roomId
        let action = AceAction.SetRoomName(roomName: roomId)
        store.ace.dispatch(action)

        let vc = AceViewController.instantiate(fromAppStoryboard: .Ace)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func launchQRScanner(dict: NSDictionary) {
        let nvc = QRCodeSCanner()
        nvc.delegate = self
        self.navigationController?.pushViewController(nvc, animated: true)
    }
    
    func launchARScene(dict: NSDictionary) {
        let nvc = AceAnimatorViewController()
        nvc.delegate = self
        self.navigationController?.pushViewController(nvc, animated: true)
    }
    
    func launchOCRScanner(dict: NSDictionary) {
        var options = [String]()
        if let arr1 = dict["options"] as? [String:Any] {
            if let arr2 = arr1["data"] as? [Any] {
                for object in arr2 {
                    if let item = object as? [String: Any] {
                        if let itemName = item["name"] as? String {
                            options.append(itemName)
                        }
                    }
                }
            }
        }
        let nvc = OCRScanner(options: options)
        nvc.delegate = self
        self.navigationController?.pushViewController(nvc, animated: true)
    }
        
}
    
extension ChatViewController : QRCodeScannerDelegate {
    func qrCodeScannerResponse(code: String) {
        webView.evaluateJavaScript("onQRCodeScanned('\(code)')", completionHandler: nil)
    }
}

extension ChatViewController : OCRDelegate {
        func ocrResponse(text: String) {
            self.webView.evaluateJavaScript("onOCRScanned('\(text)')", completionHandler: nil)
            //self.navigationController?.popViewController(animated: true)
    }
}

extension ChatViewController : AceAnimatorDelegate {
        func aceAnimatorResponse(text: String) {
            self.webView.evaluateJavaScript("onARSceneResponse('\(text)')", completionHandler: nil)
            //self.navigationController?.popViewController(animated: true)
    }
}

extension ChatViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("error: \(error)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("provisional nav error: \(error)")
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // allow any ssl cert
        let cred = URLCredential.init(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, cred)
    }
}

extension ChatViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "launchRA", let dict = message.body as? NSDictionary {
            launchRA(dict: dict)
        } else if message.name == "launchQRScanner", let dict = message.body as? NSDictionary {
            launchQRScanner(dict: dict)
        } else if message.name == "launchOCRScanner", let dict = message.body as? NSDictionary {
            launchOCRScanner(dict: dict)
        } else if message.name == "launchARScene", let dict = message.body as? NSDictionary {
            launchARScene(dict: dict)
        }
    }
}
