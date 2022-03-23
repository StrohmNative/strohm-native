import Foundation
import WebKit
import Combine

public class StrohmNative: NSObject, WKNavigationDelegate {
    public static var `default`: StrohmNative = {
        let strohmNative = StrohmNative()
        strohmNative.install(appJsPath: "main.js")
        return strohmNative
    }()

    var webView: StrohmNativeWebView?
    var webConfiguration: WKWebViewConfiguration!
    var _status = CurrentValueSubject<Status, Never>(.uninitialized)
    public lazy var status = _status.eraseToAnyPublisher()
    var appJsPath: String?
    var port: Int?
    var comms = JsonComms()
    var subscriptions: Subscriptions?
    var statePersister: StatePersister?

    static func determinePort(port: Int?, env: [String: String]) -> Int {
        if let portString = env["DEVSERVER_PORT"],
           let portInt = Int(portString),
           port == nil {
            return portInt
        } else {
            return port ?? 8080
        }
    }

    public func install(appJsPath: String, port: Int? = nil) {
        self.subscriptions = Subscriptions(strohmNative: self)
        self.statePersister = StatePersister(strohmNative: self)

        self.appJsPath = appJsPath
        self.port = port

        webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController.add(comms, name: "jsToSwift")

        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView?.navigationDelegate = self

        self.reload()
    }

    public func reload() {
        var initialStateVar = ""
        if let initialState = statePersister?.loadState() {
            let escaped = initialState.replacingOccurrences(of: "\"", with: "\\\"")
            initialStateVar = "var strohmNativePersistedState=\"\(escaped)\";"
        }
        #if DEBUG
        guard let appJsPath = self.appJsPath else { return }
        let devhost: String
        #if !targetEnvironment(simulator)
        if let devhostFile = Bundle.main.url(forResource: "devhost", withExtension: "txt"),
           let contents = try? String(contentsOf: devhostFile) {
            devhost = contents.trimmingCharacters(in: .whitespacesAndNewlines) + ".local"
        } else {
            print("\nStrohmNative error: You don't seem to have configured the Stohm Dev Support shell script build phase. Please add it to make things work.\n") // TODO: ref to doc
            devhost = "localhost"
        }
        #else
        devhost = "localhost"
        #endif
        let port = StrohmNative.determinePort(port: self.port,
                                              env: ProcessInfo().environment)
        let myHtml = """
        <html>
        <body style='background-color: #ddd;font-size: 200%'>
            <h1>Hi!</h1><div id='content'></div>
            <script>\(initialStateVar)</script>
            <script src="http://\(devhost):\(port)/\(appJsPath)"></script>
        </body>
        </html>
        """
        let baseUrl = URL(string: "http://\(devhost):\(port)/")!
        _ = webView?.loadHTMLString(myHtml, baseURL: baseUrl)
        #else
        guard let mainJSURL = Bundle.main.url(forResource: "main", withExtension: "js") else {
            print("\nStrohmNative error: JavaScript bundle main.js was not found; did you add it to the Xcode project?\n") // TODO: ref to doc
            return
        }
        let jsUrlString = mainJSURL.absoluteString
        let myHtml = """
        <html>
        <body style='background-color: #ddd;font-size: 200%'>
            <h1>Hi!</h1><div id='content'></div>
            <script>\(initialStateVar)</script>
            <script src="\(jsUrlString)"></script>
        </body>
        </html>
        """
        _ = webView?.loadHTMLString(myHtml, baseURL: Bundle.main.resourceURL)
        #endif

    }

    public func subscribe(propsSpec: PropsSpec,
                          handler: @escaping HandlerFunction,
                          completion: @escaping (UUID) -> Void) {
        self.subscriptions?.addSubscriber(propsSpec: propsSpec, handler: handler, completion: completion)
    }

    public func subscribe2(propsSpec: PropsSpec,
                           handler: @escaping HandlerFunction2,
                           completion: @escaping (UUID) -> Void) {
        self.subscriptions?.addSubscriber2(propsSpec: propsSpec, handler: handler, completion: completion)
    }

    public func unsubscribe(subscriptionId: UUID) {
        self.subscriptions?.removeSubscriber(subscriptionId: subscriptionId)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("Object.getOwnPropertyNames(strohm_native.flow)") { (result, error) in
            print("StrohmNative store properties:", result ?? "nil")
        }

        webView.evaluateJavaScript("this.hasOwnProperty('strohm_native')") { (result, error) in
            guard let returnValue = result as? Int,
                  returnValue == 1,
                  error == nil else {
                self.loadingFailed()
                return
            }
            self.loadingFinished()
        }
    }

    func loadingFinished() {
        self._status.value = .ok
        self.subscriptions?.effectuatePendingSubscriptions()
    }

    func loadingFailed() {
        self._status.value = .serverNotRunning
        print("\nStrohmNative error: Please make sure dev server is running\n") // TODO: ref to doc
    }

    func call(method: String) {
        webView?.evaluateJavaScript(method) { (result, error) in
            print("cljs call result error: \(String(describing: error))")
        }
    }

    public func dispatch<T: Encodable>(type: String, payload: T) throws {
        let encodedPayload: [String: Any] = try DictionaryEncoder().encode(payload)
        dispatch(type: type, payload: encodedPayload)
    }

    public func dispatch(type: String, payload: [String: Any] = [:]) {
        Log.debug("dispatch-swift", type, payload, "foo", 1)
        let action: [String: Any] = ["type": type, "payload": payload]
        guard let serializedAction = comms.encode(object: action) else {
            return
        }
        let method = "globalThis.strohm_native.flow.dispatch_from_native(\"\(serializedAction)\")"
        call(method: method)
    }

    public enum Status: String {
        case uninitialized = "uninitialized"
        case loading = "loading"
        case serverNotRunning = "server not running"
        case ok = "ok"
    }
}

public typealias PropName = String
public typealias PropPath = [Any]
public typealias PropsSpec = (PropName, PropPath)
public typealias Props = [PropName: Any]
public typealias HandlerFunction = (Props) -> Void
public typealias HandlerFunction2 = (String) -> Void

protocol StrohmNativeWebView {
    var navigationDelegate: WKNavigationDelegate? { get set }
    func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation?
    func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)?)
}

extension WKWebView: StrohmNativeWebView {}
