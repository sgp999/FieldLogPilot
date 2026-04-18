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
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        DispatchQueue.main.async {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.locationStatus = "Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude)"
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationStatus = "Unable to get location"
        }
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Main App
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
                    }

                    Button("Take Odometer Photo") {
                        focusedField = false
                        showCamera = true
                    }
                }

                Section(header: Text("Location")) {
                    Text(locationManager.locationStatus)

                    Button("Get Location") {
                        focusedField = false
                        locationManager.requestLocation()
                    }
                }

                Button("Start Shift") {
                    focusedField = false
                    onStartShift(locationManager.latitude, locationManager.longitude)
                }
                .disabled(odometerImage == nil || locationManager.latitude == nil)
            }

            Button("Log Out") {
                onLogout()
            }
            .foregroundColor(.red)
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $odometerImage)
        }
    }
}

// MARK: - Active Shift
struct ActiveShiftScreen: View {
    let assignmentName: String
    let shiftStartTime: Date

    var onEndShift: () -> Void
    var onLogout: () -> Void

    @State private var photos: [UIImage] = []
    @State private var showCamera = false
    @State private var noteText = ""

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Shift Info")) {
                    Text("Assignment: \(assignmentName)")
                    Text("Start: \(shiftStartTime.formatted())")
                }

                Section(header: Text("Photos")) {
                    if photos.isEmpty {
                        Text("No photos yet")
                    }

                    ForEach(photos, id: \.self) { img in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                    }

                    Button("Take Photo") {
                        showCamera = true
                    }
                }

                Section(header: Text("Notes")) {
                    TextField("Enter notes...", text: $noteText)
                }

                Button("End Shift") {
                    onEndShift()
                }
            }

            Button("Log Out") {
                onLogout()
            }
            .foregroundColor(.red)
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: Binding(
                get: { nil },
                set: { newImage in
                    if let img = newImage {
                        photos.append(img)
                    }
                }
            ))
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
                Section(header: Text("Location")) {
                    Text(locationManager.locationStatus)

                    Button("Get Location") {
                        locationManager.requestLocation()
                    }
                }

                Button("Submit Shift") {
                    onSubmit(locationManager.latitude, locationManager.longitude)
                }
            }

            Button("Log Out") {
                onLogout()
            }
            .foregroundColor(.red)
            .padding()
        }
    }
}
