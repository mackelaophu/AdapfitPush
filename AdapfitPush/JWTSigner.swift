import Foundation
import Security
import CryptoKit

/// Signs a Google JWT (RS256) using the private key from a Service Account JSON
/// and exchanges it for an OAuth2 access token.
struct JWTSigner {

    private static let googleTokenURL = "https://oauth2.googleapis.com/token"

    // MARK: - Public API

    static func fetchAccessToken(serviceAccount: ServiceAccount) async throws -> String {
        let jwt = try buildJWT(serviceAccount: serviceAccount)
        return try await exchangeJWT(jwt: jwt, tokenURL: serviceAccount.tokenUri)
    }

    // MARK: - JWT Construction

    private static func buildJWT(serviceAccount: ServiceAccount) throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let header = ["alg": "RS256", "typ": "JWT"]
        let claims: [String: Any] = [
            "iss":   serviceAccount.clientEmail,
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud":   serviceAccount.tokenUri,
            "iat":   now,
            "exp":   now + 3600
        ]

        let headerB64  = try base64url(json: header)
        let claimsB64  = try base64url(json: claims)
        let signingInput = "\(headerB64).\(claimsB64)"

        let signature = try sign(input: signingInput, pemKey: serviceAccount.privateKey)
        return "\(signingInput).\(signature)"
    }

    // MARK: - RS256 Signing

    private static func sign(input: String, pemKey: String) throws -> String {
        let secKey = try importPEMPrivateKey(pemKey)

        var error: Unmanaged<CFError>?
        guard let signedData = SecKeyCreateSignature(
            secKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            Data(input.utf8) as CFData,
            &error
        ) as Data? else {
            throw error!.takeRetainedValue()
        }

        return base64urlEncode(signedData)
    }

    /// Imports a PEM private key string (PKCS#8 "BEGIN PRIVATE KEY") into a SecKey.
    /// Strips the PKCS#8 wrapper to get the inner PKCS#1 RSAPrivateKey DER blob,
    /// then calls SecKeyCreateWithData.
    ///
    /// PKCS#8 PrivateKeyInfo DER layout (RFC 5958):
    ///   SEQUENCE {
    ///     INTEGER version (0)          ← byte[4] = 0x02
    ///     SEQUENCE { OID, NULL }       ← AlgorithmIdentifier
    ///     OCTET STRING { <pkcs1> }     ← the inner RSAPrivateKey
    ///   }
    private static func importPEMPrivateKey(_ pem: String) throws -> SecKey {
        let derData = try pemToDER(pem)
        let pkcs1   = try unwrapPKCS8(derData)

        let attrs: CFDictionary = [
            kSecAttrKeyType:       kSecAttrKeyTypeRSA,
            kSecAttrKeyClass:      kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: 2048
        ] as CFDictionary

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(pkcs1 as CFData, attrs, &error) else {
            throw error!.takeRetainedValue()
        }
        return key
    }

    /// Decode PEM base64 body to DER bytes (handles real newlines and JSON-escaped \n).
    private static func pemToDER(_ pem: String) throws -> Data {
        let normalized = pem.replacingOccurrences(of: "\\n", with: "\n")
        let b64 = normalized
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty && !$0.allSatisfy(\.isWhitespace) }
            .joined()
        guard !b64.isEmpty, let data = Data(base64Encoded: b64) else {
            throw AppError.invalidPrivateKey("PEM base64 decode failed")
        }
        return data
    }

    /// Unwrap PKCS#8 PrivateKeyInfo and return the inner PKCS#1 RSAPrivateKey DER.
    /// If the data is already PKCS#1 (starts with SEQUENCE + version INTEGER),
    /// it is returned unchanged.
    private static func unwrapPKCS8(_ der: Data) throws -> Data {
        let bytes = [UInt8](der)
        var i = 0

        // Helper: read a DER TLV length field
        func readLen() throws -> Int {
            guard i < bytes.count else { throw AppError.invalidPrivateKey("DER truncated at length") }
            let b = Int(bytes[i]); i += 1
            if b & 0x80 == 0 { return b }
            let n = b & 0x7f
            guard n > 0, i + n <= bytes.count else { throw AppError.invalidPrivateKey("DER bad length") }
            var len = 0
            for _ in 0..<n { len = (len << 8) | Int(bytes[i]); i += 1 }
            return len
        }

        // Must start with SEQUENCE
        guard bytes[i] == 0x30 else { throw AppError.invalidPrivateKey("DER: expected SEQUENCE") }
        i += 1
        _ = try readLen()  // outer SEQUENCE length (skip)

        // PKCS#8: next is INTEGER version (0x02 0x01 0x00)
        // PKCS#1: next is also INTEGER version (0x02 0x01 0x00) — identical opener
        // Distinguish them by what follows the version:
        //   PKCS#8: SEQUENCE (AlgorithmIdentifier) → tag 0x30
        //   PKCS#1: INTEGER (modulus n)             → tag 0x02
        guard bytes[i] == 0x02 else { throw AppError.invalidPrivateKey("DER: expected INTEGER") }
        i += 1
        let vLen = try readLen()
        i += vLen  // skip version value

        if bytes[i] == 0x02 {
            // Already PKCS#1 (next field is an INTEGER = modulus)
            return der
        }

        // PKCS#8: skip AlgorithmIdentifier SEQUENCE
        guard bytes[i] == 0x30 else { throw AppError.invalidPrivateKey("DER: expected AlgorithmIdentifier SEQUENCE") }
        i += 1
        let algLen = try readLen()
        i += algLen

        // OCTET STRING wrapping the inner PKCS#1
        guard i < bytes.count, bytes[i] == 0x04 else {
            throw AppError.invalidPrivateKey("DER: expected OCTET STRING, got \(String(format:"0x%02x", bytes[i]))")
        }
        i += 1
        let keyLen = try readLen()
        guard i + keyLen <= bytes.count else { throw AppError.invalidPrivateKey("DER: OCTET STRING overflows data") }
        return Data(bytes[i ..< i + keyLen])
    }

    // MARK: - Helpers

    private static func base64url(json: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: json)
        return base64urlEncode(data)
    }

    private static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Token Exchange

    private static func exchangeJWT(jwt: String, tokenURL: String) async throws -> String {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network("Không có HTTP response")
        }

        if httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            throw AppError.network("Token exchange thất bại (\(httpResponse.statusCode)): \(body)")
        }

        struct TokenResponse: Decodable {
            let access_token: String
        }
        let tokenResp = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResp.access_token
    }
}

// MARK: - App Error

enum AppError: LocalizedError {
    case invalidPrivateKey(String)
    case network(String)
    case fcm(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey(let msg): return "Private key không hợp lệ: \(msg)"
        case .network(let msg):           return "Lỗi mạng: \(msg)"
        case .fcm(let code, let msg):     return "FCM lỗi \(code): \(msg)"
        }
    }
}
