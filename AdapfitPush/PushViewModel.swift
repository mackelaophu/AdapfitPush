import SwiftUI
import UniformTypeIdentifiers

@MainActor
class PushViewModel: ObservableObject {
    // Service Account
    @Published var serviceAccount: ServiceAccount? = nil
    @Published var serviceAccountFileName: String = "Chưa chọn file"

    // Target
    @Published var useTopicMode: Bool = true
    @Published var topic: String = "adapfit_vi"
    @Published var deviceToken: String = ""

    // Notification
    @Published var title: String = "Adapfit"
    @Published var body: String  = "Xin chào! Đây là thông báo test từ Firebase."

    // Data payload
    @Published var forceUpdateMinVersion: String = "1.0.0"
    @Published var optionalUpdateMinVersion: String = ""
    @Published var screenId: String = ""

    // APNS
    @Published var apnsPushType: String = "alert"
    @Published var apnsPriority: String = "10"
    @Published var sound: String = "default"
    @Published var badge: Int = 1

    // State
    @Published var isSending: Bool = false
    @Published var logs: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: String
        let message: String
        let isError: Bool
    }

    func loadServiceAccount(from url: URL) {
        do {
            let sa = try ServiceAccount.load(from: url)
            serviceAccount = sa
            serviceAccountFileName = url.lastPathComponent
            addLog("✅ Đã load: \(url.lastPathComponent)")
            addLog("   Project: \(sa.projectId)")
            addLog("   Email:   \(sa.clientEmail)")
        } catch {
            addLog("❌ Không load được file: \(error.localizedDescription)", isError: true)
        }
    }

    func send() {
        guard let sa = serviceAccount else {
            addLog("❌ Chưa chọn Service Account JSON", isError: true)
            return
        }

        if useTopicMode && topic.trimmingCharacters(in: .whitespaces).isEmpty {
            addLog("❌ Topic không được để trống", isError: true)
            return
        }
        if !useTopicMode && deviceToken.trimmingCharacters(in: .whitespaces).isEmpty {
            addLog("❌ Device Token không được để trống", isError: true)
            return
        }

        let config = FCMService.PushConfig(
            title: title,
            body: body,
            topic: useTopicMode ? topic : "",
            deviceToken: useTopicMode ? "" : deviceToken,
            forceUpdateMinVersion: forceUpdateMinVersion,
            optionalUpdateMinVersion: optionalUpdateMinVersion,
            screenId: screenId,
            apnsPushType: apnsPushType,
            apnsPriority: apnsPriority,
            sound: sound,
            badge: badge
        )

        isSending = true
        if useTopicMode {
            addLog("→ Gửi đến topic: \(topic)")
        } else {
            addLog("→ Gửi đến device token: \(deviceToken.prefix(20))...")
        }
        addLog("  Title: \(title)")
        addLog("  Body:  \(body)")

        Task {
            do {
                let messageId = try await FCMService.send(config: config, serviceAccount: sa)
                addLog("✅ Gửi thành công!")
                addLog("   Message ID: \(messageId)")
            } catch {
                addLog("❌ \(error.localizedDescription)", isError: true)
            }
            isSending = false
        }
    }

    private func addLog(_ message: String, isError: Bool = false) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        logs.append(LogEntry(timestamp: timestamp, message: message, isError: isError))
    }

    func clearLogs() {
        logs.removeAll()
    }
}
