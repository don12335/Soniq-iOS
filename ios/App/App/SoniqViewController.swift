import UIKit
import WebKit
import Capacitor

/// Capacitor's bridge view controller plus the soniq-media:// scheme used to stream audio
/// (see MediaProxySchemeHandler). Main.storyboard uses this class.
class SoniqViewController: CAPBridgeViewController {
    private let mediaProxy = MediaProxySchemeHandler()

    override func webViewConfiguration(for instanceConfiguration: InstanceConfiguration) -> WKWebViewConfiguration {
        let configuration = super.webViewConfiguration(for: instanceConfiguration)
        configuration.setURLSchemeHandler(mediaProxy, forURLScheme: MediaProxySchemeHandler.scheme)
        return configuration
    }
}
