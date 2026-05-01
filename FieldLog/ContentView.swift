import SwiftUI
import CoreLocation
import Combine
import UIKit
import Foundation

enum AppScreen {
    case roleSelection
    case login
    case startShift
    case activeShift
    case endShift
    case ownerHome
}

enum UserRole {
    case fieldOperative
    case owner
}


// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var locationStatus: String = "Location not loaded"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            locationStatus = "Requesting permission..."
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = "Getting location..."
            manager.requestLocation()

        case .denied, .restricted:
            locationStatus = "Location access denied"

        @unknown default:
            locationStatus = "Unknown status"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationStatus = ""
                manager.requestLocation()
            case .denied, .restricted:
                self.locationStatus = "Location access denied"
            case .notDetermined:
                self.locationStatus = "Location permission not decided"
            @unknown default:
                self.locationStatus = "Unknown status"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        DispatchQueue.main.async {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.locationStatus = ""
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationStatus = "Unable to get location"
        }
    }
}


// MARK: - Main View
struct ContentView: View {
    @State private var currentScreen: AppScreen = .roleSelection
    @State private var selectedRole: UserRole? = nil

    @State private var username = ""
    @State private var password = ""

    @State private var assignmentName = ""
    @State private var shiftStartTime = Date()

    @State private var startLatitude: Double?
    @State private var startLongitude: Double?

    @State private var isShiftActive = false
    @State private var shiftPhotos: [UIImage] = []
    @State private var shiftNotes = ""
    @State private var lastSavedNoteText = ""
    @State private var activeShiftID: String?
    @State private var activeOperativeUsername = ""
    @State private var apiErrorMessage = ""
    @State private var showAPIError = false

    var body: some View {
        NavigationStack {
            switch currentScreen {

            case .roleSelection:
                RoleSelectionScreen(
                    onSelectFieldOperative: {
                        selectedRole = .fieldOperative
                        currentScreen = .login
                    },
                    onSelectOwner: {
                        selectedRole = .owner
                        currentScreen = .login
                    }
                )

            case .login:
                LoginScreen(
                    username: $username,
                    password: $password,
                    onLogin: {
                        if selectedRole == .owner {
                            currentScreen = .ownerHome
                        } else {
                            currentScreen = .startShift
                        }
                    },
                    onBackHome: {
                        username = ""
                        password = ""
                        selectedRole = nil
                        currentScreen = .roleSelection
                    }
                )

            case .startShift:
                StartShiftScreen(
                    assignmentName: $assignmentName,
                    onStartShift: { lat, lon, odometerImage in
                        guard let lat, let lon else {
                            apiErrorMessage = "Location is required to start a shift."
                            showAPIError = true
                            return
                        }

                        let trimmedAssignment = assignmentName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedAssignment.isEmpty else {
                            apiErrorMessage = "Assignment name is required."
                            showAPIError = true
                            return
                        }

                        let startTime = Date()
                        API.startShift(
                            operativeName: username,
                            assignmentName: trimmedAssignment,
                            lat: lat,
                            lon: lon
                        ) { response in
                            guard let response else {
                                apiErrorMessage = "Unable to start shift on the backend."
                                showAPIError = true
                                return
                            }

                            shiftStartTime = startTime
                            startLatitude = lat
                            startLongitude = lon
                            activeShiftID = response.id
                            activeOperativeUsername = response.operative_name
                            shiftNotes = ""
                            lastSavedNoteText = ""
                            isShiftActive = true

                            if let odometerImage {
                                API.uploadPhoto(shiftId: response.id, image: odometerImage) { success in
                                    if !success {
                                        apiErrorMessage = "Shift started, but odometer photo failed to upload."
                                        showAPIError = true
                                    }
                                    currentScreen = .activeShift
                                }
                            } else {
                                currentScreen = .activeShift
                            }
                        }
                    },
                    onLogout: { resetApp() }
                )

            case .activeShift:
                ActiveShiftScreen(
                    activeShiftID: activeShiftID,
                    assignmentName: assignmentName,
                    operativeUsername: activeOperativeUsername,
                    shiftStartTime: shiftStartTime,
                    startLatitude: startLatitude,
                    startLongitude: startLongitude,
                    photos: $shiftPhotos,
                    noteText: $shiftNotes,
                    onEndShift: {
                        currentScreen = .endShift
                    },
                    onLogout: { resetApp() },
                    onViewOwner: {
                        currentScreen = .ownerHome
                    },
                    onSaveNote: { text in
                        guard let activeShiftID else {
                            apiErrorMessage = "No active shift ID found."
                            showAPIError = true
                            return
                        }

                        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedText.isEmpty else {
                            apiErrorMessage = "Note cannot be empty."
                            showAPIError = true
                            return
                        }

                        guard trimmedText != lastSavedNoteText else {
                            apiErrorMessage = "That note is already saved."
                            showAPIError = true
                            return
                        }

                        API.addNote(shiftId: activeShiftID, text: trimmedText) { success in
                            if success {
                                lastSavedNoteText = trimmedText
                            } else {
                                apiErrorMessage = "Unable to save note to the backend."
                                showAPIError = true
                            }
                        }
                    },
                    onUploadPhoto: { image in
                        guard let activeShiftID else {
                            apiErrorMessage = "No active shift ID found."
                            showAPIError = true
                            return
                        }

                        API.uploadPhoto(shiftId: activeShiftID, image: image) { success in
                            if !success {
                                apiErrorMessage = "Unable to upload photo to the backend."
                                showAPIError = true
                            }
                        }
                    }
                )

            case .endShift:
                EndShiftScreen(
                    onSubmit: { lat, lon in
                        guard let lat, let lon else {
                            apiErrorMessage = "Ending location is required."
                            showAPIError = true
                            return
                        }

                        guard let activeShiftID else {
                            apiErrorMessage = "No active shift ID found."
                            showAPIError = true
                            return
                        }

                        API.endShift(shiftId: activeShiftID, lat: lat, lon: lon) { success in
                            if success {
                                isShiftActive = false
                                resetApp()
                            } else {
                                apiErrorMessage = "Unable to end shift on the backend."
                                showAPIError = true
                            }
                        }
                    },
                    onLogout: { resetApp() }
                )

            case .ownerHome:
                OwnerHomeScreen(
                    onLogout: { resetApp() }
                )
            }
        }
        .alert("Backend Error", isPresented: $showAPIError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(apiErrorMessage)
        }
    }

    func resetApp() {
        username = ""
        password = ""
        assignmentName = ""
        activeOperativeUsername = ""
        shiftStartTime = Date()
        startLatitude = nil
        startLongitude = nil
        shiftPhotos = []
        shiftNotes = ""
        lastSavedNoteText = ""
        activeShiftID = nil
        apiErrorMessage = ""
        showAPIError = false
        isShiftActive = false
        selectedRole = nil
        currentScreen = .roleSelection
    }
}

// MARK: - Role Selection
struct RoleSelectionScreen: View {
    var onSelectFieldOperative: () -> Void
    var onSelectOwner: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Agency")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 60) {   // ← increase this number
                Text("FieldLog Pilot")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select User Type")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 40) {
                Button("Field Operative") {
                    onSelectFieldOperative()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(.top, 40)
        .padding()
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Login
struct LoginScreen: View {
    @Binding var username: String
    @Binding var password: String
    var onLogin: () -> Void
    var onBackHome: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Pierog Detective Agency")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Field Log")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Login")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                TextField("Username (use demo)", text: $username)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password (use demo)", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            Button("Log In") {
                onLogin()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            Button("Back to Home") {
                onBackHome()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(.top, 40)
        .padding()
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Start Shift
struct StartShiftScreen: View {
    @Binding var assignmentName: String

    var onStartShift: (_ lat: Double?, _ lon: Double?, _ odometerImage: UIImage?) -> Void
    var onLogout: () -> Void

    @StateObject private var locationManager = LocationManager()

    @State private var odometerImage: UIImage?
    @State private var showCamera = false

    @FocusState private var focusedField: Bool

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Assignment")) {
                    TextField("Assignment Name", text: $assignmentName)
                        .focused($focusedField)
                }

                Section(header: Text("Odometer")) {
                    if let image = odometerImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                    } else {
                        Text("No photo taken")
                            .foregroundColor(.secondary)
                    }

                    Button("Take Odometer Photo") {
                        focusedField = false
                        showCamera = true
                    }
                }

                Section(header: Text("Current Location")) {
                    Button("Get Location") {
                        focusedField = false
                        locationManager.requestLocation()
                    }

                    if let lat = locationManager.latitude,
                       let lon = locationManager.longitude {
                        HStack {
                            Text("Lat:")
                                .fontWeight(.semibold)
                            Text("\(lat, specifier: "%.6f")")

                            Spacer()

                            Text("Lon:")
                                .fontWeight(.semibold)
                            Text("\(lon, specifier: "%.6f")")
                        }
                        .font(.subheadline)
                    } else {
                        Text("Location not selected yet")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }

                    if !locationManager.locationStatus.isEmpty {
                        Text(locationManager.locationStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Start Shift") {
                    focusedField = false
                    onStartShift(locationManager.latitude, locationManager.longitude, odometerImage)
                }
                .disabled(
                    odometerImage == nil ||
                    locationManager.latitude == nil ||
                    locationManager.longitude == nil
                )
            }

            Button("Log Out") {
                onLogout()
            }
            .foregroundColor(.red)
            .padding()
        }
        .sheet(isPresented: $showCamera, onDismiss: {
            focusedField = false
        }) {
            ImagePicker(selectedImage: $odometerImage)
        }
    }
}

// MARK: - Active Shift
struct ActiveShiftScreen: View {
    let activeShiftID: String?
    let assignmentName: String
    let operativeUsername: String
    let shiftStartTime: Date
    let startLatitude: Double?
    let startLongitude: Double?

    @Binding var photos: [UIImage]
    @Binding var noteText: String

    var onEndShift: () -> Void
    var onLogout: () -> Void
    var onViewOwner: () -> Void
    var onSaveNote: (String) -> Void
    var onUploadPhoto: (UIImage) -> Void

    @State private var showCamera = false
    @State private var latestPhoto: UIImage?
    @StateObject private var locationManager = LocationManager()
    @State private var trackingTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    @FocusState private var notesFocused: Bool

    private func sendLiveLocationUpdate() {
        guard let activeShiftID else { return }

        locationManager.requestLocation()

        guard let lat = locationManager.latitude,
              let lon = locationManager.longitude else {
            return
        }

        API.updateLocation(shiftId: activeShiftID, lat: lat, lon: lon) { success in
            if !success {
                print("Live location update failed")
            }
        }
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Shift Info")) {
                    Text("Assignment: \(assignmentName)")
                    Text("Operative: \(operativeUsername)")
                    Text("Start: \(shiftStartTime.formatted())")

                    if let lat = startLatitude, let lon = startLongitude {
                        Text("GPS: \(lat), \(lon)")
                    }
                }

                Section(header: Text("Photos")) {
                    Button("Take Photo") {
                        notesFocused = false
                        showCamera = true
                    }

                    if photos.isEmpty {
                        Text("No photos yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(photos.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                        }
                    }
                }

                Section(header: Text("Notes")) {
                    ZStack(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("Enter notes...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $noteText)
                            .frame(minHeight: 180)
                            .padding(4)
                            .focused($notesFocused)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )

                    Button("Save Note") {
                        notesFocused = false
                        onSaveNote(noteText)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("End Shift") {
                    notesFocused = false
                    onEndShift()
                }
            }
            .scrollDismissesKeyboard(.interactively)

            Button("Log Out") {
                notesFocused = false
                onLogout()
            }
            .foregroundColor(.red)
            .padding()
        }
        .onAppear {
            locationManager.requestLocation()
            sendLiveLocationUpdate()
        }
        .onReceive(trackingTimer) { _ in
            sendLiveLocationUpdate()
        }
        .sheet(isPresented: $showCamera, onDismiss: {
            if let photo = latestPhoto {
                photos.append(photo)
                onUploadPhoto(photo)
                latestPhoto = nil
            }
        }) {
            ImagePicker(selectedImage: $latestPhoto)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    notesFocused = false
                }
            }
        }
    }
}

// MARK: - End Shift
struct EndShiftScreen: View {
    var onSubmit: (_ lat: Double?, _ lon: Double?) -> Void
    var onLogout: () -> Void

    @StateObject private var locationManager = LocationManager()

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Current Location")) {
                    Button("Get Location") {
                        locationManager.requestLocation()
                    }

                    if let lat = locationManager.latitude,
                       let lon = locationManager.longitude {
                        HStack {
                            Text("Lat:")
                                .fontWeight(.semibold)
                            Text("\(lat, specifier: "%.6f")")

                            Spacer()

                            Text("Lon:")
                                .fontWeight(.semibold)
                            Text("\(lon, specifier: "%.6f")")
                        }
                        .font(.subheadline)
                    } else {
                        Text("Location not selected yet")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }

                    if !locationManager.locationStatus.isEmpty {
                        Text(locationManager.locationStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Submit Shift") {
                        onSubmit(locationManager.latitude, locationManager.longitude)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(
                    locationManager.latitude == nil ||
                    locationManager.longitude == nil
                )
            }

            Button("Log Out") {
                onLogout()
            }
            .foregroundColor(.red)
            .padding(.bottom)
        }
        .navigationTitle("End Shift")
    }
}

// MARK: - Owner Screen
struct OwnerHomeScreen: View {
    var onLogout: () -> Void

    @State private var dashboard: OwnerDashboardResponse?
    @State private var isLoading = false
    @State private var ownerErrorMessage = ""
    @State private var showOwnerError = false

    private func fullPhotoURL(_ path: String) -> URL? {
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            return URL(string: path)
        }

        if path.hasPrefix("/") {
            return URL(string: BASE_URL + path)
        }

        return URL(string: BASE_URL + "/" + path)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Owner Dashboard")
                        .font(.title)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Refresh") {
                        loadDashboard()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Clear All") {
                        API.clearAll { success in
                            if success {
                                loadDashboard()
                            } else {
                                ownerErrorMessage = "Unable to clear logs on the backend. Make sure /admin/clear-logs exists and the backend is running."
                                showOwnerError = true
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                

                if !isLoading && dashboard == nil {
                    VStack(spacing: 10) {
                        Text("Unable to load dashboard")
                            .font(.headline)

                        Text("Make sure the FastAPI backend is running and the /shifts/active endpoint is reachable.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                if isLoading {
                    ProgressView("Loading...")
                        .padding(.top, 30)
                } else if let dashboard = dashboard, !dashboard.active_shifts.isEmpty {
                    ForEach(dashboard.active_shifts.sorted(by: { $0.start_time > $1.start_time }), id: \.id) { shift in
                        VStack(spacing: 16) {

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Shift Status")
                                    .font(.headline)

                                HStack {
                                    Text("Active")
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)

                                    Spacer()

                                    Text(shift.status.capitalized)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                Text("Assignment: \(shift.assignment_name)")
                                Text("Operative: \(shift.operative_name)")
                                Text("Start Time: \(shift.start_time)")
                                Text("Latest Location")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text("Lat:")
                                        .fontWeight(.semibold)
                                    Text("\(shift.latest_latitude, specifier: "%.6f")")

                                    Spacer()

                                    Text("Lon:")
                                        .fontWeight(.semibold)
                                    Text("\(shift.latest_longitude, specifier: "%.6f")")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Activity Summary")
                                    .font(.headline)

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Notes")
                                            .foregroundColor(.secondary)
                                        Text("\(shift.notes.count)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading) {
                                        Text("Photos")
                                            .foregroundColor(.secondary)
                                        Text("\(shift.photos.count)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Latest Note")
                                    .font(.headline)

                                if let latestNote = shift.notes.last {
                                    Text(latestNote.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(latestNote.created_at)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No notes yet")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Odometer Photo")
                                    .font(.headline)

                                if let odometerPhoto = shift.photos.first {
                                    AsyncImage(url: fullPhotoURL(odometerPhoto.url)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .cornerRadius(10)
                                        case .failure:
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.title)
                                                    .foregroundColor(.secondary)
                                                Text("Unable to load photo")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 120)
                                        case .empty:
                                            ProgressView()
                                                .frame(maxWidth: .infinity, minHeight: 120)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }

                                    Text(odometerPhoto.uploaded_at)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No odometer photo yet")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Latest Surveillance Photo")
                                    .font(.headline)

                                if shift.photos.count > 1, let latestSurveillancePhoto = shift.photos.last {
                                    AsyncImage(url: fullPhotoURL(latestSurveillancePhoto.url)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .cornerRadius(10)
                                        case .failure:
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.title)
                                                    .foregroundColor(.secondary)
                                                Text("Unable to load photo")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 120)
                                        case .empty:
                                            ProgressView()
                                                .frame(maxWidth: .infinity, minHeight: 120)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }

                                    Text(latestSurveillancePhoto.uploaded_at)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No surveillance photos yet")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("All Notes")
                                    .font(.headline)

                                if shift.notes.isEmpty {
                                    Text("No notes yet")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(shift.notes) { note in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(note.text)
                                            Text(note.created_at)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 6)

                                        Divider()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("No Active Shifts")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("When a field operative starts a shift, it will appear here.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                }

                Button("Log Out") {
                    onLogout()
                }
                .foregroundColor(.red)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Owner")
        .alert("Clear All Failed", isPresented: $showOwnerError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(ownerErrorMessage)
        }
        .onAppear {
            loadDashboard()
        }
    }

    private func loadDashboard() {
        isLoading = true
        dashboard = nil

        API.fetchOwnerDashboard { response in
            dashboard = response
            isLoading = false
        }
    }
}
