import Foundation

@Observable
final class SessionManager {
    private var sessionStartTime: Date?
    private var initialContent: String = ""
    private var currentContent: String = ""

    var isSessionActive: Bool {
        sessionStartTime != nil
    }

    func startSession(with content: String) {
        sessionStartTime = Date()
        initialContent = content
        currentContent = content
    }

    func updateContent(_ content: String) {
        currentContent = content
    }

    func endSession() -> SessionResult {
        guard let startTime = sessionStartTime else {
            return SessionResult(countsAsProgress: false, duration: 0)
        }

        let duration = Date().timeIntervalSince(startTime)
        let contentChanged = currentContent != initialContent
        let countsAsProgress = duration >= 30 && contentChanged

        sessionStartTime = nil
        initialContent = ""
        currentContent = ""

        return SessionResult(countsAsProgress: countsAsProgress, duration: duration)
    }
}

struct SessionResult {
    let countsAsProgress: Bool
    let duration: TimeInterval
}
