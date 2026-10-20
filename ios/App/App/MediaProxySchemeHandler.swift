import Foundation
import WebKit

/// Streams remote audio for the web app's <audio> element through URLSession.
///
/// WebKit's media loader can't send the Origin/Referer/User-Agent headers YouTube's media
/// servers expect, so the web app points <audio> at
/// `soniq-media://stream?url=<https URL>&h=<JSON headers>` instead. Each request (including the
/// Range requests WebKit makes while buffering and seeking) is forwarded with those headers and
/// the response is passed back chunk by chunk, so playback starts as soon as data arrives and
/// nothing is written to disk.
final class MediaProxySchemeHandler: NSObject, WKURLSchemeHandler, URLSessionDataDelegate {
    static let scheme = "soniq-media"

    // delegate callbacks run on the main queue, the same thread WebKit calls start/stop on,
    // so the task maps below need no locking
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    private var schemeTasks: [Int: WKURLSchemeTask] = [:]
    private var dataTasks: [ObjectIdentifier: URLSessionDataTask] = [:]

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let request = upstreamRequest(for: urlSchemeTask.request) else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let task = session.dataTask(with: request)
        schemeTasks[task.taskIdentifier] = urlSchemeTask
        dataTasks[ObjectIdentifier(urlSchemeTask)] = task
        task.resume()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // WebKit stops tasks when it has buffered enough or the source changes; calling the
        // scheme task after this point would throw, so forget it before cancelling
        guard let task = dataTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask)) else { return }
        schemeTasks.removeValue(forKey: task.taskIdentifier)
        task.cancel()
    }

    private func upstreamRequest(for request: URLRequest) -> URLRequest? {
        guard let url = request.url,
              let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let target = query.first(where: { $0.name == "url" })?.value,
              let targetURL = URL(string: target),
              targetURL.scheme == "https" else { return nil }

        var upstream = URLRequest(url: targetURL)
        if let encoded = query.first(where: { $0.name == "h" })?.value,
           let data = encoded.data(using: .utf8),
           let headers = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for (name, value) in headers {
                upstream.setValue(value, forHTTPHeaderField: name)
            }
        }
        if let range = request.value(forHTTPHeaderField: "Range") {
            upstream.setValue(range, forHTTPHeaderField: "Range")
        }
        return upstream
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let schemeTask = schemeTasks[dataTask.taskIdentifier], let url = schemeTask.request.url else {
            completionHandler(.cancel)
            return
        }
        if let http = response as? HTTPURLResponse {
            var headers: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                guard let name = key as? String, let text = value as? String else { continue }
                // URLSession already decoded the body
                if name.caseInsensitiveCompare("Content-Encoding") == .orderedSame { continue }
                headers[name] = text
            }
            let proxied = HTTPURLResponse(url: url, statusCode: http.statusCode, httpVersion: "HTTP/1.1", headerFields: headers)
            schemeTask.didReceive(proxied ?? response)
        } else {
            schemeTask.didReceive(response)
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        schemeTasks[dataTask.taskIdentifier]?.didReceive(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let schemeTask = schemeTasks.removeValue(forKey: task.taskIdentifier) else { return }
        dataTasks.removeValue(forKey: ObjectIdentifier(schemeTask))
        if let error = error {
            schemeTask.didFailWithError(error)
        } else {
            schemeTask.didFinish()
        }
    }
}
