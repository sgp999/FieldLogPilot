import SwiftUI
import CoreLocation
import Combine

enum AppScreen {
    case login
    case startShift
    case activeShift
    case endShift
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
    @State private var currentScreen: AppScreen = .login

    @State private var username = ""
    @State private var password = ""

    @State private var assignmentName = ""
    @State private var shiftStartTime = Date()

    @State private var startLatitude: Double?
    @State private var startLongitude: Double?

    var body: some View {
        NavigationStack {
            switch currentScreen {

            case .login:
                LoginScreen(
                    username: $username,
                    password: $password,
                    onLogin: {
                        currentScreen = .startShift
                    }
                )

            case .startShift:
                StartShiftScreen(
                    assignmentName: $assignmentName,
                    onStartShift: { lat, lon in
                        shiftStartTime = Date()
                        startLatitude = lat
                        startLongitude = lon
                        currentScreen = .activeShift
                    },
                    onLogout: { resetApp() }
                )

            case .activeShift:
                ActiveShiftScreen(
                    assignmentName: assignmentName,
                    shiftStartTime: shiftStartTime,
                    startLatitude: startLatitude,
                    startLongitude: startLongitude,
                    onEndShift: {
                        currentScreen = .endShift
                    },
                    onLogout: { resetApp() }
                )

            case .endShift:
                EndShiftScreen(
                    onSubmit: { _, _ in
                        resetApp()
                    },
                    onLogout: { resetApp() }
                )
            }
        }
    }

    func resetApp() {
        username = ""
        password = ""
        assignmentName = ""
        currentScreen = .login
    }
}

// MARK: - Login
struct LoginScreen: View {
    @Binding var username: String
    @Binding var password: String
    var onLogin: () -> Void

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
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            Button("Log In") {
                onLogin()
            }
            .buttonStyle(.borderedProminent)

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

    var onStartShift: (_ lat: Double?, _ lon: Double?) -> Void
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
                    onStartShift(locationManager.latitude, locationManager.longitude)
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
    let assignmentName: String
    let shiftStartTime: Date
    let startLatitude: Double?
    let startLongitude: Double?

    var onEndShift: () -> Void
    var onLogout: () -> Void

    @State private var photos: [UIImage] = []
    @State private var showCamera = false
    @State private var latestPhoto: UIImage?
    @State private var noteText = ""

    @FocusState private var notesFocused: Bool

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Shift Info")) {
                    Text("Assignment: \(assignmentName)")
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
        .sheet(isPresented: $showCamera, onDismiss: {
            if let photo = latestPhoto {
                photos.append(photo)
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
