//
//  ProductionStravaService.swift
//  Compound
//
//  Created by Andrew Coyle on 09/03/2026.
//

import Foundation
import FirebaseFunctions

struct ProductionStravaService: StravaService {

    private let functions = Functions.functions(region: "us-central1")
    // Safe: a valid URL literal.
    private let apiURL = URL(string: "https://www.strava.com/api/v3")!

    func connect(code: String?, refreshToken: String?, clientId: String) async throws -> StravaConnectResult {
        var payload = ["clientId": clientId]
        payload["code"] = code
        payload["refreshToken"] = refreshToken
        return try await call("stravaConnect", payload)
    }

    func connection() async throws -> StravaAthlete? {
        struct Answer: Decodable { let athlete: StravaAthlete? }
        let answer: Answer = try await call("stravaConnection")
        return answer.athlete
    }

    func accessToken() async throws -> StravaAccessToken {
        try await call("stravaAccessToken")
    }

    func disconnect() async throws {
        _ = try await functions.httpsCallable("stravaDisconnect").call()
    }

    /// A `strava*` callable, its errors read as the app's: permission-denied is Strava refusing
    /// the grant, not-found no connection, failed-precondition a grant without the upload permission.
    private func call<T: Decodable>(_ name: String, _ payload: [String: String] = [:]) async throws -> T {
        let result: HTTPSCallableResult
        do {
            result = try await functions.httpsCallable(name).call(payload)
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: error.code) {
            case .permissionDenied: throw StravaError.authorizationRevoked
            case .notFound: throw StravaError.notConnected
            case .failedPrecondition: throw StravaError.missingUploadPermission
            default: throw error
            }
        }
        let data = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func upload(_ upload: StravaUpload, accessToken: String) async throws -> StravaUploadStatus {
        let boundary = "Compound-\(UUID().uuidString)"
        var request = request(path: "uploads", method: "POST", accessToken: accessToken)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.multipartBody(upload, boundary: boundary)
        let (data, status) = try await send(request)
        // A file Strava refuses outright, a duplicate included, is a 400 whose body is a status.
        if (200...299).contains(status) || status == 400,
           let answer = try? JSONDecoder().decode(StravaUploadStatus.self, from: data) {
            return answer
        }
        throw StravaError.uploadFailed(status: status)
    }

    func uploadStatus(id: Int, accessToken: String) async throws -> StravaUploadStatus {
        let (data, status) = try await send(request(path: "uploads/\(id)", method: "GET", accessToken: accessToken))
        guard (200...299).contains(status) else { throw StravaError.uploadFailed(status: status) }
        return try JSONDecoder().decode(StravaUploadStatus.self, from: data)
    }

    func updateActivity(id: Int, name: String, description: String?, accessToken: String) async throws {
        var request = request(path: "activities/\(id)", method: "PUT", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // An empty description clears it; leaving the key out would keep the old one.
        request.httpBody = try JSONEncoder().encode(["name": name, "description": description ?? ""])
        let (_, status) = try await send(request)
        guard (200...299).contains(status) else { throw StravaError.uploadFailed(status: status) }
    }

    // MARK: - Helpers

    private func request(path: String, method: String, accessToken: String) -> URLRequest {
        var request = URLRequest(url: apiURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// The body and status, with a 401 — a token Strava no longer accepts — and a 429 — over
    /// Strava's request limit — thrown as such.
    private func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw StravaError.authorizationRevoked }
        if status == 429 { throw StravaError.rateLimited }
        return (data, status)
    }

    static func multipartBody(_ upload: StravaUpload, boundary: String) throws -> Data {
        var fields = [
            ("data_type", "json"),
            ("sport_type", "WeightTraining"),
            ("external_id", upload.externalId),
            ("name", upload.name)
        ]
        if let description = upload.description { fields.append(("description", description)) }

        var body = Data()
        for (name, value) in fields {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"workout.json\"\r\nContent-Type: application/json\r\n\r\n".utf8))
        body.append(try JSONEncoder().encode(upload.file))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}
