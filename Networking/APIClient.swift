import Foundation

struct UploadResult: Decodable {
    let name: String?
    let path: String?
    let error: String?
}

struct TmuxWindow: Decodable, Identifiable {
    let index: Int
    let name: String
    let active: Bool
    let command: String

    var id: Int { index }
}

struct TmuxWindowsResponse: Decodable {
    let windows: [TmuxWindow]
}

struct CopyResponse: Decodable {
    let text: String
}

struct SessionClaimResponse: Decodable {
    let session_id: String
}

struct SessionCheckResponse: Decodable {
    let active: Bool
    let current_device: String?
}

class APIClient {
    var baseURL: String = ""

    // MARK: - Session Claim

    func claimSession(deviceName: String) async throws -> String {
        let url = URL(string: "\(baseURL)/session/claim")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["device": deviceName])
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SessionClaimResponse.self, from: data)
        return response.session_id
    }

    func checkSession(sessionId: String) async throws -> SessionCheckResponse {
        let url = URL(string: "\(baseURL)/session/check/\(sessionId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SessionCheckResponse.self, from: data)
    }

    // MARK: - Photo Upload

    func uploadImage(_ imageData: Data, name: String) async throws -> UploadResult {
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UploadResult.self, from: data)
    }

    // MARK: - Terminal Copy

    func capturePane(session: String = "claude") async throws -> String {
        let url = URL(string: "\(baseURL)/copy")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(CopyResponse.self, from: data)
        return response.text
    }

    // MARK: - tmux Window Management

    func listWindows() async throws -> [TmuxWindow] {
        let url = URL(string: "\(baseURL)/tmux/windows")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TmuxWindowsResponse.self, from: data)
        return response.windows
    }

    func selectWindow(index: Int) async throws {
        let url = URL(string: "\(baseURL)/tmux/window/select")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["index": index])
        let _ = try await URLSession.shared.data(for: request)
    }

    func newWindow(command: String? = nil) async throws {
        let url = URL(string: "\(baseURL)/tmux/window/new")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: String] = [:]
        if let command { payload["command"] = command }
        request.httpBody = try JSONEncoder().encode(payload)
        let _ = try await URLSession.shared.data(for: request)
    }

    func closeWindow(index: Int) async throws {
        let url = URL(string: "\(baseURL)/tmux/window/close")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["index": index])
        let _ = try await URLSession.shared.data(for: request)
    }

    func execCommand(_ command: String, window: String? = nil) async throws {
        let url = URL(string: "\(baseURL)/tmux/exec")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: String] = ["command": command]
        if let window { payload["window"] = window }
        request.httpBody = try JSONEncoder().encode(payload)
        let _ = try await URLSession.shared.data(for: request)
    }
}
