import SwiftUI

enum AppScreen {
    case login
    case startShift
    case activeShift
    case endShift
}

struct ContentView: View {
    @State private var currentScreen: AppScreen = .login
    @State private var assignmentName = ""
    @State private var startMileage = ""
    @State private var endMileage = ""
    @State private var shiftStartTime = Date()

    var body: some View {
        NavigationStack {
            switch currentScreen {
            case .login:
                LoginScreen {
                    currentScreen = .startShift
                }

            case .startShift:
                StartShiftScreen(
                    assignmentName: $assignmentName,
                    startMileage: $startMileage,
                    onStartShift: {
                        shiftStartTime = Date()
                        currentScreen = .activeShift
                    }
                )

            case .activeShift:
                ActiveShiftScreen(
                    assignmentName: assignmentName,
                    shiftStartTime: shiftStartTime,
                    onEndShift: {
                        currentScreen = .endShift
                    }
                )

            case .endShift:
                EndShiftScreen(
                    endMileage: $endMileage,
                    onClockOut: {
                        assignmentName = ""
                        startMileage = ""
                        endMileage = ""
                        currentScreen = .startShift
                    }
                )
            }
        }
    }
}

struct LoginScreen: View {
    @State private var email = ""
    @State private var password = ""
    var onLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("FieldLog")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Log field work, photos, and mileage")
                .foregroundColor(.secondary)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button(action: onLogin) {
                Text("Log In")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
    }
}

struct StartShiftScreen: View {
    @Binding var assignmentName: String
    @Binding var startMileage: String
    @State private var notes = ""
    var onStartShift: () -> Void

    var body: some View {
        Form {
            Section("Start Shift") {
                TextField("Assignment Name", text: $assignmentName)
                TextField("Starting Mileage", text: $startMileage)
                    .keyboardType(.numberPad)
                TextField("Notes (optional)", text: $notes)

                Button("Add Start Odometer Photo") {
                    print("Photo picker later")
                }
            }

            Section {
                Button(action: onStartShift) {
                    Text("Start Shift")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Start Shift")
    }
}

struct ActiveShiftScreen: View {
    let assignmentName: String
    let shiftStartTime: Date
    var onEndShift: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(assignmentName.isEmpty ? "No Assignment" : assignmentName)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Shift started: \(shiftStartTime.formatted(date: .omitted, time: .shortened))")
                .foregroundColor(.secondary)

            Button("Add Note") {
                print("Add note later")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)

            Button("Add Photo") {
                print("Add photo later")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)

            Button("Check-In") {
                print("Check-in later")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)

            Spacer()

            Button(action: onEndShift) {
                Text("End Shift")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .navigationTitle("Active Shift")
    }
}

struct EndShiftScreen: View {
    @Binding var endMileage: String
    @State private var finalNotes = ""
    var onClockOut: () -> Void

    var body: some View {
        Form {
            Section("End Shift") {
                TextField("Ending Mileage", text: $endMileage)
                    .keyboardType(.numberPad)

                TextField("Final Notes (optional)", text: $finalNotes)

                Button("Add End Odometer Photo") {
                    print("Photo picker later")
                }
            }

            Section {
                Button(action: onClockOut) {
                    Text("Clock Out")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("End Shift")
    }
}

#Preview {
    ContentView()
}
