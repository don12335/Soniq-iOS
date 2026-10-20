import Foundation
import Capacitor

/// Native HTTP for the web app's fetch wrapper (src/shared/platform/native/nativeFetch.ts in Soniq).
///
/// Capacitor's built-in CapacitorHttp parses any `application/json` response itself and drops the
/// body when that fails. YouTube's sw.js_data is served as JSON with a `)]}'` prefix, so the app
/// never got its visitor id and every player request was answered with a bot check. This plugin
/// passes bodies through untouched: request and response bodies are base64 strings.
@objc(SoniqHttpPlugin)
public class SoniqHttpPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SoniqHttpPlugin"
    public let jsName = "SoniqHttp"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "request", returnType: CAPPluginReturnPromise)
    ]

    private let session = URLSession(configuration: .default)

    @objc func request(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url"), let url = URL(string: urlString) else {
            call.reject("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = call.getString("method") ?? "GET"
        request.timeoutInterval = (call.getDouble("timeout") ?? 30_000) / 1000
        for (name, value) in call.getObject("headers") ?? [:] {
            if let text = value as? String {
                request.setValue(text, forHTTPHeaderField: name)
            }
        }
        if let body = call.getString("body"), let data = Data(base64Encoded: body) {
            request.httpBody = data
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                call.reject(error.localizedDescription, nil, error)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                call.reject("No HTTP response")
                return
            }
            var headers: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                guard let name = key as? String else { continue }
                let lower = name.lowercased()
                // URLSession already decoded the body
                if lower == "content-encoding" { continue }
                headers[lower] = "\(value)"
            }
            call.resolve([
                "status": http.statusCode,
                "headers": headers,
                "url": http.url?.absoluteString ?? urlString,
                "data": (data ?? Data()).base64EncodedString(),
            ])
        }.resume()
    }
}
