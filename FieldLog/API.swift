import Foundation
import UIKit

let BASE_URL = "https://fieldlog-backend.onrender.com"

// MARK: - Start Shift Response
struct StartShiftResponse: Decodable {
    let id: String
    let operative_name: String
    let assignment_name: String
    let start_time: String
    let start_latitude: Double
    let start_longitude: Double
    let latest_latitude: Double
    let latest_longitude: Double
    let status: String

    init(
        id: String,
        operative_name: String,
        assignment_name: String,
        start_time: String,
        start_latitude: Double,
        start_longitude: Double,
        latest_latitude: Double,
        latest_longitude: Double,
        status: String
    ) {
        self.id = id
        self.operative_name = operative_name
        self.assignment_name = assignment_name
        self.start_time = start_time
        self.start_latitude = start_latitude
        self.start_longitude = start_longitude
        self.latest_latitude = latest_latitude
        self.latest_longitude = latest_longitude
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case operative_name
        case assignment_name
        case start_time
        case start_latitude
        case start_longitude
        case latest_latitude
        case latest_longitude
        case status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(String.self, forKey: .id)
        assignment_name = try c.decode(String.self, forKey: .assignment_name)

        start_time = (try? c.decode(String.self, forKey: .start_time)) ?? ""
        start_latitude = (try? c.decode(Double.self, forKey: .start_latitude)) ?? 0
        start_longitude = (try? c.decode(Double.self, forKey: .start_longitude)) ?? 0
        latest_latitude = (try? c.decode(Double.self, forKey: .latest_latitude)) ?? start_latitude
        latest_longitude = (try? c.decode(Double.self, forKey: .latest_longitude)) ?? start_longitude
        status = (try? c.decode(String.self, forKey: .status)) ?? "active"

        if let name = try? c.decode(String.self, forKey: .operative_name) {
            operative_name = name
        } else if let username = try? c.decode(String.self, forKey: .username) {
            operative_name = username
        } else {
            operative_name = "demo"
        }
    }
}

// MARK: - Models
struct OwnerDashboardResponse: Decodable {
    let active_shifts: [ActiveShift]
}

struct ActiveShift: Decodable, Identifiable {
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

struct ShiftNote: Decodable, Identifiable {
    let id: String
    let text: String
    let created_at: String
}

struct ShiftPhoto: Decodable, Identifiable {
    let id: String
    let filename: String
    let url: String
    let uploaded_at: String
}

// MARK: - Request Bodies
private struct EndShiftRequestBody: Encodable {
    let end_latitude: Double
    let end_longitude: Double
}

private struct UpdateLocationRequestBody: Encodable {
    let latitude: Double
    let longitude: Double
}

// MARK: - API
final class API {
    @MainActor static var lastStartShiftError: String = ""

    // MARK: Start Shift
    static func startShift(
        operativeName: String,
        assignmentName: String,
        lat: Double,
        lon: Double,
        completion: @escaping @MainActor (StartShiftResponse?) -> Void
    ) {
        print("🔥 startShift CALLED")
        print("🧪 About to send request to backend")
        NSLog("🔥 startShift CALLED")
        Task { @MainActor in API.lastStartShiftError = "" }

        guard let url = URL(string: "\(BASE_URL)/shifts/start") else {
            print("BAD URL")
            NSLog("BAD URL")
            Task { @MainActor in
                API.lastStartShiftError = "Bad backend URL."
                completion(nil)
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "username": operativeName,
            "assignment_name": assignmentName,
            "start_latitude": lat,
            "start_longitude": lon
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("START SHIFT BODY:", body)

        URLSession.shared.dataTask(with: request) { data, response, error in

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response"

            print("✅ STATUS:", statusCode)
            print("📦 RESPONSE:", responseText)
            NSLog("START SHIFT STATUS: \(statusCode)")
            NSLog("START SHIFT RESPONSE: \(responseText)")

            if let error {
                print("NETWORK ERROR:", error.localizedDescription)
                NSLog("NETWORK ERROR: \(error.localizedDescription)")
                Task { @MainActor in
                    API.lastStartShiftError = "Network error: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }

            guard (200...299).contains(statusCode), let data else {
                Task { @MainActor in
                    API.lastStartShiftError = "Backend status \(statusCode): \(responseText)"
                    completion(nil)
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(StartShiftResponse.self, from: data)
                Task { @MainActor in completion(decoded) }
            } catch {
                print("DECODE ERROR:", error.localizedDescription)
                NSLog("DECODE ERROR: \(error.localizedDescription)")

                if let fallback = API.makeFallbackStartShiftResponse(
                    data: data,
                    operativeName: operativeName,
                    assignmentName: assignmentName,
                    lat: lat,
                    lon: lon
                ) {
                    Task { @MainActor in completion(fallback) }
                    return
                }

                Task { @MainActor in
                    API.lastStartShiftError = "Decode error: \(error.localizedDescription). Response: \(responseText)"
                    completion(nil)
                }
            }

        }.resume()
    }

    private static func makeFallbackStartShiftResponse(
        data: Data,
        operativeName: String,
        assignmentName: String,
        lat: Double,
        lon: Double
    ) -> StartShiftResponse? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let root = jsonObject as? [String: Any] else {
            return nil
        }

        let shift = (root["shift"] as? [String: Any]) ??
                    (root["data"] as? [String: Any]) ??
                    root

        let idValue = shift["id"] ?? shift["shift_id"] ?? root["id"] ?? root["shift_id"]

        let id: String
        if let stringId = idValue as? String {
            id = stringId
        } else if let intId = idValue as? Int {
            id = String(intId)
        } else if let doubleId = idValue as? Double {
            id = String(Int(doubleId))
        } else {
            return nil
        }

        let returnedUsername =
            shift["operative_name"] as? String ??
            shift["username"] as? String ??
            root["operative_name"] as? String ??
            root["username"] as? String ??
            operativeName

        let returnedAssignment =
            shift["assignment_name"] as? String ??
            root["assignment_name"] as? String ??
            assignmentName

        let returnedStartTime =
            shift["start_time"] as? String ??
            root["start_time"] as? String ??
            ISO8601DateFormatter().string(from: Date())

        let returnedStatus =
            shift["status"] as? String ??
            root["status"] as? String ??
            "active"

        let startLat =
            shift["start_latitude"] as? Double ??
            root["start_latitude"] as? Double ??
            lat

        let startLon =
            shift["start_longitude"] as? Double ??
            root["start_longitude"] as? Double ??
            lon

        let latestLat =
            shift["latest_latitude"] as? Double ??
            root["latest_latitude"] as? Double ??
            startLat

        let latestLon =
            shift["latest_longitude"] as? Double ??
            root["latest_longitude"] as? Double ??
            startLon

        return StartShiftResponse(
            id: id,
            operative_name: returnedUsername,
            assignment_name: returnedAssignment,
            start_time: returnedStartTime,
            start_latitude: startLat,
            start_longitude: startLon,
            latest_latitude: latestLat,
            latest_longitude: latestLon,
            status: returnedStatus
        )
    }

    // MARK: Add Note
    static func addNote(
        shiftId: String,
        text: String,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
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
            let success = error == nil && (200...299).contains(statusCode)

            Task { @MainActor in
                completion(success)
            }
        }.resume()
    }

    // MARK: Upload Photo
    static func uploadPhoto(
        shiftId: String,
        image: UIImage,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            print("UPLOAD PHOTO FAILED: could not create JPEG data")
            Task { @MainActor in completion(false) }
            return
        }

        let uploadAttempts: [(route: String, fieldName: String)] = [
            ("/shifts/\(shiftId)/photo", "file"),
            ("/shifts/\(shiftId)/photo", "photo"),
            ("/shifts/\(shiftId)/photo", "image"),
            ("/shifts/\(shiftId)/photos", "file"),
            ("/shifts/\(shiftId)/photos", "photo"),
            ("/shifts/\(shiftId)/photos", "image")
        ]

        func tryUpload(index: Int) {
            guard index < uploadAttempts.count else {
                print("UPLOAD PHOTO FAILED: all attempts failed")
                Task { @MainActor in completion(false) }
                return
            }

            let attempt = uploadAttempts[index]

            guard let url = URL(string: BASE_URL + attempt.route) else {
                tryUpload(index: index + 1)
                return
            }

            let boundary = UUID().uuidString

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(attempt.fieldName)\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            print("UPLOAD PHOTO TRY:", url.absoluteString, "field:", attempt.fieldName)

            URLSession.shared.dataTask(with: request) { data, response, error in
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response"

                print("UPLOAD PHOTO STATUS:", statusCode)
                print("UPLOAD PHOTO RESPONSE:", responseText)

                if error == nil && (200...299).contains(statusCode) {
                    Task { @MainActor in completion(true) }
                } else {
                    tryUpload(index: index + 1)
                }
            }.resume()
        }

        tryUpload(index: 0)
    }

    // MARK: Update Location
    static func updateLocation(
        shiftId: String,
        lat: Double,
        lon: Double,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        guard let url = URL(string: "\(BASE_URL)/shifts/\(shiftId)/location") else {
            Task { @MainActor in completion(false) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = UpdateLocationRequestBody(latitude: lat, longitude: lon)
        request.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Task { @MainActor in
                completion((200...299).contains(statusCode) && error == nil)
            }
        }.resume()
    }

    // MARK: Fetch Dashboard
    static func fetchOwnerDashboard(
        completion: @escaping @MainActor (OwnerDashboardResponse?) -> Void
    ) {
        guard let url = URL(string: "\(BASE_URL)/shifts/active") else {
            Task { @MainActor in completion(nil) }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            let response = data.flatMap {
                try? JSONDecoder().decode(OwnerDashboardResponse.self, from: $0)
            }
            Task { @MainActor in completion(response) }
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
            Task { @MainActor in
                completion((200...299).contains(statusCode) && error == nil)
            }
        }.resume()
    }

    // MARK: End Shift
    static func endShift(
        shiftId: String,
        lat: Double,
        lon: Double,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
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
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Task { @MainActor in
                completion((200...299).contains(statusCode) && error == nil)
            }
        }.resume()
    }
}
