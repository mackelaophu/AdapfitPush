import Foundation

struct ServiceAccount: Codable {
    let type: String
    let projectId: String
    let privateKeyId: String
    let privateKey: String
    let clientEmail: String
    let clientId: String
    let authUri: String
    let tokenUri: String
    let authProviderX509CertUrl: String
    let clientX509CertUrl: String

    enum CodingKeys: String, CodingKey {
        case type
        case projectId                  = "project_id"
        case privateKeyId               = "private_key_id"
        case privateKey                 = "private_key"
        case clientEmail                = "client_email"
        case clientId                   = "client_id"
        case authUri                    = "auth_uri"
        case tokenUri                   = "token_uri"
        case authProviderX509CertUrl    = "auth_provider_x509_cert_url"
        case clientX509CertUrl          = "client_x509_cert_url"
    }

    static func load(from url: URL) throws -> ServiceAccount {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ServiceAccount.self, from: data)
    }
}
