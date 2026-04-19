import Foundation
import UIKit

let BASE_URL = "http://192.168.1.70:8000"

// MARK: - Start Shift Response
struct StartShiftResponse: Decodable, Sendable {
    let id: Int
    let assignment_name: String
    let start_time: String
    let start_latitude: Double
    let start_longitude: Double
    let status: String
}

// MARK: - Note Response
struct NoteResponse: Decodable, Sendable {
    let text: String
    let created_at: String
}

// MARK: - Owner Dashboard Models
struct OwnerDashboardResponse: Decodable, Sendable {
    let active_shifts: [ActiveShift]
}

struct ActiveShift: Decodable, Sendable, Identifiable {
    let id: Int
    let assignment_name: String
    let start_time: String
    let start_latitude: Double
    let start_longitude: Double
    let status: String
    let notes: [ShiftNote]
    let photos: [ShiftPhoto]
}

struct ShiftNote: Decodable, Sendable, Identifiable {
    let id = UUID()
    let text: String
    let created_at: String

    enum CodingKeys: String, CodingKey {
        case text
        case created_at
    }
}

struct ShiftPhoto: Decodable, Sendable, Identifiable {
    let id = UUID()
    let file_path: String
    let url: String
    let filename: String
    let uploaded_at: String

    enum CodingKeys: String, CodingKey {
        case file_path
        case url
        case filename
        case uploaded_at
    }
}

private struct EndShiftRequestBody: Encodable, Sendable {
    let end_latitude: Double
    let end_longitude: Double
}

// MARK: - API
final class API {

    // MARK: Start Shift
    static func startShift(lat: Double, lon: Double, completion: @escaping @MainActor (StartShiftResponse?) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/shifts/start") else {
            Task { @MainActor in completion(nil) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "start_latitude": lat,
            "start_longitude": lon
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                Task { @MainActor in completion(nil) }
                return
            }

            Task { @MainActor in
                let response = try? JSONDecoder().decode(StartShiftResponse.self, from: data)
                completion(response)
            }
        }.resume()
    }

    // MARK: Add Note
    static func addNote(shiftId: Int, text: String, completion: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/shifts/\(shiftId)/notes") else {
            Task { @MainActor in completion(false) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                Task { @MainActor in completion(false) }
                return
            }

            Task { @MainActor in
                let success = (try? JSONDecoder().decode(NoteResponse.self, from: data)) != nil
                completion(success)
            }
        }.resume()
    }

    // MARK: Upload Photo
    static func uploadPhoto(shiftId: Int, image: UIImage, completion: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/shifts/\(shiftId)/photos") else {
            Task { @MainActor in completion(false) }
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            Task { @MainActor in completion(false) }
            return
        }

        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200

            Task { @MainActor in
                completion(ok && error == nil && data != nil)
            }
        }.resume()
    }

    // MARK: Fetch Owner Dashboard
    static func fetchOwnerDashboard(completion: @escaping @MainActor (OwnerDashboardResponse?) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/owner/dashboard") else {
            Task { @MainActor in completion(nil) }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                Task { @MainActor in completion(nil) }
                return
            }

            Task { @MainActor in
                let response = try? JSONDecoder().decode(OwnerDashboardResponse.self, from: data)
                completion(response)
            }
        }.resume()
    }

    // MARK: End Shift
    static func endShift(shiftId: Int, lat: Double, lon: Double, completion: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/shifts/\(shiftId)/end") else {
            Task { @MainActor in completion(false) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = EndShiftRequestBody(
            end_latitude: lat,
            end_longitude: lon
        )

        request.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200

            Task { @MainActor in
                completion(ok && error == nil)
            }
        }.resume()
    }
}
