import Foundation

struct FCMService {

    struct PushConfig {
        var title: String
        var body: String
        var topic: String
        var deviceToken: String
        var forceUpdateMinVersion: String
        var apnsPushType: String
        var apnsPriority: String
        var sound: String
        var badge: Int
    }

    static func send(config: PushConfig, serviceAccount: ServiceAccount) async throws -> String {
        // Step 1: Get access token
        let accessToken = try await JWTSigner.fetchAccessToken(serviceAccount: serviceAccount)

        // Step 2: Build payload
        let urlString = "https://fcm.googleapis.com/v1/projects/\(serviceAccount.projectId)/messages:send"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let target: [String: Any]
        if !config.topic.trimmingCharacters(in: .whitespaces).isEmpty {
            target = ["topic": config.topic.trimmingCharacters(in: .whitespaces)]
        } else {
            target = ["token": config.deviceToken.trimmingCharacters(in: .whitespaces)]
        }

        var payload: [String: Any] = [
            "notification": [
                "title": config.title,
                "body":  config.body
            ],
            "data": [
                "force_update_min_version": config.forceUpdateMinVersion
            ],
            "apns": [
                "headers": [
                    "apns-push-type": config.apnsPushType,
                    "apns-priority":  config.apnsPriority
                ],
                "payload": [
                    "aps": [
                        "alert": [
                            "title": config.title,
                            "body":  config.body
                        ],
                        "sound": config.sound,
                        "badge": config.badge
                    ]
                ]
            ]
        ]

        // Merge target into payload
        for (k, v) in target { payload[k] = v }

        let body = ["message": payload]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Step 3: Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network("Không có HTTP response từ FCM")
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        if httpResponse.statusCode == 200 {
            // Parse message ID
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["name"] as? String {
                return name
            }
            return "(Gửi thành công)"
        } else {
            throw AppError.fcm(httpResponse.statusCode, responseText)
        }
    }
}
