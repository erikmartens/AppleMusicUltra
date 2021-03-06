//
//  ViewController.swift
//  Apple Music
//
//  Created by Justin Bush on 2020-03-03.
//  Copyright © 2020 Justin Bush. All rights reserved.
//

import Cocoa
import WebKit
import AVKit
import MediaPlayer

// MediaPlayer Control Centre
// https://developer.apple.com/documentation/mediaplayer/remote_command_center_events

// System Variables
let App = NSApplication.shared
let Defaults = UserDefaults.standard
let Notification = NotificationCenter.default

struct Music {
    static let app = "Apple Music Web Client"
    static let url = "https://beta.music.apple.com"
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.5 Safari/605.1.15"
    // https://beta.music.apple.com/for-you
}

struct Preset {
    static let theme = Defaults.object(forKey: "theme") as? NSVisualEffectView.Material ?? .sheet
    static let type  = Defaults.string(forKey: "type") ?? "setTheme"
    static let media = Defaults.string(forKey: "media") ?? ""
    
    static let imURL = Defaults.url(forKey: "mediafile")
    static let style = Defaults.string(forKey: "style")
}


let debug = true
var lastURL = ""

class ViewController: NSViewController, WKUIDelegate, WKNavigationDelegate, NSWindowDelegate {

    let hasLaunched = Defaults.bool(forKey: "hasLaunchedBefore")
    
    // MARK: Variables
    @IBOutlet var webView: WKWebView!
    @IBOutlet var titleBar: NSTextField!
    @IBOutlet var blur: NSVisualEffectView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet var topConstraint: NSLayoutConstraint!
    
    // WebView URL Observer
    var webViewURLObserver: NSKeyValueObservation?
    var webViewTitleObserver: NSKeyValueObservation?
    
    private var loginWindowController: LoginWindowController?
    
    private var loginWebView: WKWebView?
    private var window: WindowController?
    let windowController: WindowController = WindowController()
    
    var nowURL = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if debug {
            print("url hasLaunchedBefore: \(hasLaunched)")
            print("urlDidLoad Defaults(type: \(Preset.type), theme: \(Preset.theme), media: \(Preset.media)")
        }
        //Defaults.set(false, forKey: "hasLaunchedBefore")
        
        // WebView Configuration
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        webView.customUserAgent = Music.userAgent
        webView.configuration.applicationNameForUserAgent = Music.userAgent
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
        configuration.allowsAirPlayForMediaPlayback = true
        webView.configuration.allowsAirPlayForMediaPlayback = true
        
        // Load Apple Music Web Beta
        webView.load(Music.url)
        
        // WebView URL Observer (Detect Changes)
        webViewURLObserver = webView.observe(\.url, options: .new) { webView, change in
            let url = "\(String(describing: change.newValue))"
            ViewController().urlChange(urlString: url)
        }
        
        // WebView Title Observer
        webViewTitleObserver = self.observe(\.webView.title, options: .new) { webView, change in
            let title = "\(String(describing: change.newValue))"
            ViewController().titleChange(pageTitle: title)
        }
        
        imageView.imageScaling = .scaleAxesIndependently
        
        if debug {
            topConstraint.constant = 0
        }
        
    }
    
    override func viewWillAppear() {
        self.view.window?.delegate = self
        
        let sheet = NSVisualEffectView.Material.sheet
        
        if hasLaunched {
            //setTheme(theme: Preset.theme, withMedia: Preset.media)
            setThemeManager(theme: Preset.theme, type: Preset.type, media: Preset.media)
        } else {
            setTheme(theme: sheet)
            Defaults.set(true, forKey: "hasLaunchedBefore")
        }
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.delegate = self
    }
    
    
    func windowDidResize(_ notification: Notification) {
        // This will print the window's size each time it is resized.
        print("urlSize:", view.window!.frame.size)
    }
    
    private func windowDidResize(notification: NSNotification) {
        print("URL Size:", view.window!.frame.size)
    }
    
    // MARK: WKWebView
    
    func titleChange(pageTitle: String) {
        //self.view.window?.delegate = self
        print("url start title:", pageTitle)
        // Fix Optional URL String
        var title = pageTitle.replacingOccurrences(of: "Optional", with: "")
        let brackets: Set<Character> = ["(", ")"]
        title.removeAll(where: { brackets.contains($0) })
        print("url New Title:", title)
        
        self.view.window?.title = title
        self.view.window?.update()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //let css = "style.css".isValidFile()
        
        // Add default CSS stylesheet
        let path = Bundle.main.path(forResource: "style", ofType: "css", inDirectory: "Resources")
        var cssString: String? = nil
        do {
            cssString = try String(contentsOfFile: path ?? "", encoding: .ascii)
        } catch {
        }
        cssString = cssString?.replacingOccurrences(of: "\n", with: "")
        cssString = cssString?.replacingOccurrences(of: "\"", with: "'")
        cssString = cssString?.replacingOccurrences(of: "Optional(", with: "")
        cssString = cssString?.replacingOccurrences(of: "\")", with: "")
        
        let css = cssString!
        
        //print("url css:", css)
        let js = "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    
    // TO DO:
    // Close login popup on this button click:
    // <button data-targetid="continue" data-pageid="WebPlayerConfirmConnection" class="button-primary signed-in" data-ember-action="" data-ember-action-286="286">Continue</button>
    // style: button.button-primary.signed-in
    
    // WebView: 650 x 710
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        loginWebView = WKWebView(frame: view.bounds, configuration: configuration)
        loginWebView!.frame = view.bounds
        self.setupConstraints(for: loginWebView!)
        loginWebView!.navigationDelegate = self
        loginWebView!.uiDelegate = self
        view.addSubview(loginWebView!)
        return loginWebView!
    }

    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        loginWebView = nil
    }
    
    // Website URL Changes Here
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url?.absoluteString
        //guard let isAuth = url?.contains("https://idmsa.apple.com/IDMSWebAuth/") else { return nil }
        
        // https://idmsa.apple.com/auth
        if let isAuth = url?.contains("https://idmsa.apple.com/IDMSWebAuth/") {
            if webView === loginWebView && isAuth {
                self.presentLoginScreen(with: loginWebView!)
            }
        }
        decisionHandler(.allow)
    }
    
    // Create new Window with Login Prompt
    private func presentLoginScreen(with loginWebView: WKWebView) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        // Instantiate login window view controller from storyboard
        if let loginWindowVC = storyboard.instantiateController(withIdentifier: "LoginWindow") as? LoginWindowController {
            // Keep reverence to it in mememory
            loginWindowController = loginWindowVC
            if let loginVC = loginWindowVC.window?.contentViewController as? LoginViewController {
                // Set preview webview
                loginVC.setWebView(loginWebView)
            }
            // Present login window to user
            loginWindowVC.showWindow(self)
        }
    }
    
    /// Called when the WKWebView's absolute URL value changes
    func urlChange(urlString: String) {
        // Fix Optional URL String
        var url = urlString.replacingOccurrences(of: "Optional", with: "")
        let brackets: Set<Character> = ["(", ")"]
        url.removeAll(where: { brackets.contains($0) })
        
        print("URL:", url)
        
        // First Session Launch Checks
        // if url = "https://beta.music.apple.com/us/browse" - User has not logged in
        // if url =
        
        // Check for Login Success (User clicked "Continue")
        // "https://authorize.music.apple.com/?liteSessionId"
        if lastURL.contains("authorize.music.apple.com") && url.contains("beta.music.apple.com") { //url.contains(Music.url) {
            print("URL detected, close Login")
            
            let loginView = LoginViewController()
            let loginWindow = LoginWindowController()
            
            loginWindow.close()
            
            loginView.dismiss(self)
            loginWindow.dismissController(self)
            //dismiss(loginWindowController)
            
            
            //loginView.closeLoginPrompt()
            loginWindow.closeLoginPrompt()
            //self.view.removeFromSuperview()
            //dismissLoginView()
            
            //loginWebView?.removeFromSuperview()
            //loginWebView = nil
            
        }
        
        lastURL = url
        nowURL = url
        print("lastURL:", lastURL)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func forceLightMode() {
        
    }
    
    func forceDarkMode() {
        
    }
    
    
    // MARK: Themes
    
    // Core Vibrant Themes
    
    // Defaults
    @IBAction func themeDefault(_ sender: Any) { setTheme(theme: .sheet) }                  // Default
    @IBAction func themeVibrant(_ sender: Any) { setTheme(theme: .toolTip) }                // Vibrant
    // Light (Force Light Mode via CSS)
    @IBAction func themeLight(_ sender: Any) { setTheme(theme: .mediumLight) }              // Light
    @IBAction func themeVibrantLight(_ sender: Any) { setTheme(theme: .light) }             // Vibrant Light
    // Dark (Force Dark Mode via CSS)
    @IBAction func themeDark(_ sender: Any) { setTheme(theme: .ultraDark) }                 // Dark
    @IBAction func themeVibrantDark(_ sender: Any) { setTheme(theme: .dark) }               // Vibrant Dark
    // Other System Themes
    @IBAction func themeFrosty(_ sender: Any) { setTheme(theme: .appearanceBased) }         // Frosty
    @IBAction func themeFlat(_ sender: Any) { setTheme(theme: .titlebar) }                  // Flat
    @IBAction func themePlain(_ sender: Any) { setTheme(theme: .headerView) }               // Plain
    @IBAction func themeOpaque(_ sender: Any) { setTheme(theme: .underPageBackground) }     // Opaque
    @IBAction func themeTemp(_ sender: Any) { setTheme(theme: .underWindowBackground) }     // Unknown (Temp)
    
    // Custom Themes
    @IBAction func themeWave(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "wave") }
    @IBAction func themePurple(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "purple") }
    @IBAction func themeSilk(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "silk") }
    @IBAction func themeBubbles(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "bubbles") }
    @IBAction func themeGoblin(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "goblin") }
    @IBAction func themeSpring(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "spring") }
    @IBAction func themeQuartz(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "quartz") }
    @IBAction func themeDunes(_ sender: Any) { setTheme(theme: .toolTip, withMedia: "dunes") }
    
    // Custom User Theme
    @IBAction func themeCustom(_ sender: Any) { setCustomTheme(theme: .toolTip) }
    
    
    // MARK: Theme Manager
    
    func setThemeManager(theme: NSVisualEffectView.Material, type: String, media: Any) {
        
        /*
        if type == "setTheme" {
            setTheme(theme: theme)
        }
        */

        
        // Media is an app background image (String)
        if let image = media as? String {
            if !(image.isEmpty) {
                setTheme(theme: theme, withMedia: image)
            } else {
                // Media is just theme
                setTheme(theme: theme)
            }
        }
        // Media is a custom user-selected image (URL)
        if let url = media as? URL {
            let urlString = url.absoluteString.removingPercentEncoding
            print("urlString: \(urlString)")
            let newURL = URL(string: urlString ?? url.absoluteString)
            setCustomTheme(theme: theme, withURL: newURL!)
        }
    }
    
    /// Set the active theme
    func setTheme(theme: NSVisualEffectView.Material) {
        imageView.alphaValue = 0
        blur.material = theme
        blur.blendingMode = .behindWindow
        saveDefaults(theme: theme, type: "setTheme", media: "")
    }
    /// Set active theme with image String
    func setTheme(theme: NSVisualEffectView.Material, withMedia: String) {
        blur.material = theme
        blur.blendingMode = .withinWindow
        setBackground(withMedia)
    }
    /// Set active theme with image URL
    func setTheme(theme: NSVisualEffectView.Material, withURL: URL) {
        blur.material = theme
        blur.blendingMode = .withinWindow
        setBackground(withURL)
    }
    func setCustomTheme(theme: NSVisualEffectView.Material) {
        let imageURL = windowController.selectImageFile()
        blur.blendingMode = .withinWindow
        setBackground(imageURL)
    }
    func setCustomTheme(theme: NSVisualEffectView.Material, withURL: URL) {
        //let imageURL = withURL
        blur.blendingMode = .withinWindow
        setBackground(withURL)
    }
    
    func themeToString(_ theme: NSVisualEffectView.Material) -> String {
        let themeString = "\(blur.material.self)" //"\(blur.material)"
        print("urlDebug: \(themeString)")
        return themeString
    }
    
    // Set background with default theme
    func setBackground(_ media: Any) {
        setBackground(theme: .sheet, media: media)
    }
    
    func setBackground(theme: NSVisualEffectView.Material, media: Any) {
        imageView.alphaValue = 1
        var mediaString = ""
        if let object = media as? String {
            let image = NSImage(named: object)
            imageView.image = image
            mediaString = object
        }
        if let object = media as? URL {
            let image = NSImage(byReferencing: object)
            imageView.image = image
            mediaString = "\(object)"
        }
        saveDefaults(theme: theme, type: "setThemeWithMedia", media: mediaString)
    }
    
    // Save UserDefaults to restore next session
    func saveDefaults(theme: NSVisualEffectView.Material, type: String, media: String) {
        let style = themeToString(theme)
        print("urlRAW: \(theme.rawValue)")
        Defaults.set(style, forKey: "style")
        Defaults.set(type, forKey: "type")
        //Defaults.set(theme, forKey: "theme")      // Crash
        Defaults.set(media, forKey: "media")
        if debug { print("urlDefaults(type: \(type), style: \(style), media: \(media)") }
    }
    
    // MARK: Settings
    
    // Toggle Music Logo (logo is at 0px top parent onShow notHidden again)
    @IBAction func toggleLogo(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        if sender.state == .on {
            //let css = ".web-navigation__logo-container { display: none; } .dt-search-box { padding-top: 20px; }"
            let css = ".web-navigation__logo-container { opacity: 0; }"
            let js = "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            //let css = ".web-navigation__logo-container { display: inline; padding-top: 20px; }"
            let css = ".web-navigation__logo-container { opacity: 100; }"
            let js = "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);"
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    // Open current page in Safari
    @IBAction func openInSafari(_ sender: NSMenuItem) {
        let url = URL(string: nowURL)
        if NSWorkspace.shared.open(url ?? URL(string: "https://beta.music.apple.com/")!) {
            print("default browser was successfully opened")

        }
    }
    
    // WindowController did enter fullscreen mode
    public func updateForFullscreenMode() {
        titleBar.isHidden = true
        topConstraint.constant = 0
    }
    
    // WindowController did enter window mode
    public func updateForWindowedMode() {
        titleBar.isHidden = false
        topConstraint.constant = 0//22.0
    }
    
    /// Dismiss Launch view with fade out animation
    private func dismissLoginView() {
        //startLaunchActivityAnimation()
        guard let loginWebView = loginWebView else {
            return
        }
        
        NSAnimationContext.runAnimationGroup({ (context) in
            NSAnimationContext.current.duration = 0.4
            loginWebView.animator().alphaValue = 0.0
        }, completionHandler: {
            loginWebView.isHidden = true
            // Remove Launch view from super view and from memory
            loginWebView.removeFromSuperview()
            self.loginWebView = nil
        })
        
        // Show initial titlebar on first launch
        //updateForWindowedMode()
    }
    


}


// MARK: Extensions

// WKWebView Extension
extension WKWebView {
    func load(_ urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            load(request)
        }
    }
}

// Checks to see if input file has contents or not
public extension String {
func isValidFile()->String {
    if let path = Bundle.main.path(forResource:self , ofType: nil) {
        do {
            let text = try String(contentsOfFile:path, encoding: String.Encoding.utf8)
            return text
            } catch { print("Failed to read text from bundle file \(self)") }
    } else { print("Failed to load file from bundle \(self)") }
    return ""
}
}

/// MARK: NSViewController extantion for constraints
extension NSViewController {
    /// Setup constraints for webview, it should be clip to bounds of the screen
    func setupConstraints(for webview: WKWebView) {
        
        webview.translatesAutoresizingMaskIntoConstraints = false
        // Add constraints to main ViewController view
        if let superView = webview.superview {
            // Top
            superView.addConstraints([NSLayoutConstraint(item: webview,
                                                         attribute: .top,
                                                         relatedBy: .equal,
                                                         toItem: superView,
                                                         attribute: .top,
                                                         multiplier: 1.0,
                                                         constant: 0.0)])
            // Bottom
            superView.addConstraints([NSLayoutConstraint(item: webview,
                                                         attribute: .bottom,
                                                         relatedBy: .equal,
                                                         toItem: superView,
                                                         attribute: .bottom,
                                                         multiplier: 1.0,
                                                         constant: 0.0)])
            // Left
            superView.addConstraints([NSLayoutConstraint(item: webview,
                                                         attribute: .left,
                                                         relatedBy: .equal,
                                                         toItem: superView,
                                                         attribute: .left,
                                                         multiplier: 1.0,
                                                         constant: 0.0)])
            // Right
            superView.addConstraints([NSLayoutConstraint(item: webview,
                                                         attribute: .right,
                                                         relatedBy: .equal,
                                                         toItem: superView,
                                                         attribute: .right,
                                                         multiplier: 1.0,
                                                         constant: 0.0)])
            
        }
    }
    
}

