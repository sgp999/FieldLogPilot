import Foundation
import UIKit

//let BASE_URL = "http://Steves-MacBook-Air.local:8000"
let BASE_URL = "http://192.168.12.168:8000"


// MARK: - Start Shift Response
struct StartShiftResponse: Decodable, Sendable {
    let id: String
    let operative_name: String
    let assignment_name: String
    let start_time: String
    let start_latitude: Double
    let start_longitude: Double
    let latest_latitude: Double
    let latest_longitude: Double
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
    let id: String
    let operative_name: String
    let assignment_name: String
    let start_time: String
    let end_time: String?
    let start_latitude: Double
    let start_longitude: Double
    let latest_latitude: Double
    let latest_longitude: Double
    let end_latitude: Double?
    let end_longitude: Double?
    let status: String
    let notes: [ShiftNote]
    let photos: [ShiftPhoto]
}

struct ShiftNote: Decodable, Sendable, Identifiable {
    let id: String
    let text: String
    let created_at: String
}

struct ShiftPhoto: Decodable, Sendable, Identifiable {
    let id: String
    let filename: String
    let url: String
    let uploaded_at: String
}

private struct EndShiftRequestBody: Encodable, Sendable {
    let end_latitude: Double
    let end_longitude: Double
}

private struct UpdateLocationRequestBody: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
}

// MARK: - API
final class API {

    // MARK: Start Shift
    static func startShift(
        operativeName: String,
        assignmentName: String,
        lat: Double,
        lon: Double,
        completion: @escaping @MainActor (StartShiftResponse?) -> Void
    ) {
        guard let url = URL(string: "\(BASE_URL)/shifts/start") else {
            print("Start shift failed: bad URL")
            Task { @MainActor in completion(nil) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "operative_name": operativeName,
            "assignment_name": assignmentName,
            "start_latitude": lat,
            "start_longitude": lon
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("START SHIFT URL:", url.absoluteString)
        print("START SHIFT BODY:", body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"

            print("START SHIFT STATUS:", statusCode)
            print("START SHIFT RESPONSE:", responseText)

            guard error == nil else {
                print("Start shift network error:", error?.localizedDescription ?? "unknown error")
                Task { @MainActor in completion(nil) }
                return
            }

            guard statusCode == 200, let data else {
                Task { @MainActor in completion(nil) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(StartShiftResponse.self, from: data)
                Task { @MainActor in completion(decoded) }
            } catch {
                print("Start shift decode error:", error.localizedDescription)
                Task { @MainActor in completion(nil) }
            }
        }.resume()
    }
    // MARK: Add Note
    static func addNote(shiftId: String, text: String, completion: @escaping @MainActor (Bool) -> Void) {
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

        URLSession.shared.dataTask(with: request) { _, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let success = error == nil && statusCode == 200

            if !success {
                print("Add note failed. Status:", statusCode, "Error:", error?.localizedDescription ?? "none")
            }

            Task { @MainActor in
                completion(success)
            }
        }.resume()
    }

    // MARK: Upload Photo
    static func uploadPhoto(shiftId: String, image: UIImage, completion: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/shifts/\(shiftId)/photo") else {
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
        guard let url = URL(string: "\(BASE_URL)/shifts/active") else {
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

    // MARK: Clear All
    static func clearAll(completion: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/admin/clear-logs") else {
            Task { @MainActor in completion(false) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { _, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let success = error == nil && statusCode == 200

            if !success {
                print("Clear all failed. Status:", statusCode, "Error:", error?.localizedDescription ?? "none")
            }

            Task { @MainActor in
                completion(success)
            }
        }.resume()
    }

    // Compatibility wrapper for older button code
    static func resetDashboard(completion: @escaping @MainActor (Bool) -> Void) {
        clearAll(completion: completion)
    }

    // MARK: Update Location
    static func updateLocation(shiftId: String, lat: Double, lon: Double, completion: @escaping @MainActor (Bool) -> Void) {
        guard let url = URL(string: "\(BASE_URL)/shifts/\(shiftId)/location") else {
            Task { @MainActor in completion(false) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = UpdateLocationRequestBody(
            latitude: lat,
            longitude: lon
        )

        request.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200

            Task { @MainActor in
                completion(ok && error == nil)
            }
        }.resume()
    }
    
    // MARK: End Shift
    static func endShift(shiftId: String, lat: Double, lon: Double, completion: @escaping @MainActor (Bool) -> Void) {
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
