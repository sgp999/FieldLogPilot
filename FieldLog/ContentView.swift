//
//  ContentView.swift
//  Content View
//
//  Created by Steve Pierog on 4/16/26.
//

import SwiftUI
import Combine
import UIKit

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
                    },
                    onBackToLogin: {
                        currentScreen = .login
                    }
                )
            case .endShift:
                EndShiftScreen(
                    onClockOut: {
                        assignmentName = ""
                        currentScreen = .login
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

    var canLogin: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("FieldLog")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Pierog Detective Agency")
                .font(.headline)
                .fontWeight(.bold)

            TextField("User Name", text: $email)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Log In") {
                if canLogin {
                    onLogin()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canLogin ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!canLogin)

            Spacer()
        }
        .padding()
    }
}

struct StartShiftScreen: View {
    @Binding var assignmentName: String

    @State private var notes = ""
    @State private var showCamera = false
    @State private var odometerPhoto: UIImage?

    @FocusState private var notesFocused: Bool
    @FocusState private var fieldFocused: Bool

    var onStartShift: () -> Void

    var canStartShift: Bool {
        !assignmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        odometerPhoto != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // HEADER (ONLY ONE TITLE NOW)
                Text("Start Shift")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // ASSIGNMENT
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assignment")
                        .font(.headline)

                    TextField("Enter assignment name", text: $assignmentName)
                        .textFieldStyle(.roundedBorder)
                        .focused($fieldFocused)
                }

                // NOTES
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.headline)

                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Enter notes (optional)")
                                .foregroundColor(.gray)
                                .padding(.top, 14)
                                .padding(.leading, 10)
                        }

                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .padding(6)
                            .focused($notesFocused)
                    }
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.5))
                    )
                }

                // ODOMETER PHOTO
                VStack(alignment: .leading, spacing: 10) {
                    Text("Starting Odometer Photo")
                        .font(.headline)

                    Button(odometerPhoto == nil ? "Take Odometer Photo" : "Retake Odometer Photo") {
                        fieldFocused = false
                        notesFocused = false
                        showCamera = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)

                    if let image = odometerPhoto {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .cornerRadius(12)
                    }
                }

                // REQUIRED MESSAGE
                if !canStartShift {
                    Text("Assignment and odometer photo are required.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // START BUTTON
                Button("Start Shift") {
                    fieldFocused = false
                    notesFocused = false
                    onStartShift()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canStartShift ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!canStartShift)

                Spacer()
            }
            .padding()
        }

        // CAMERA
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $odometerPhoto)
        }

        // KEYBOARD DONE
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    fieldFocused = false
                    notesFocused = false
                }
            }
        }

        .onTapGesture {
            fieldFocused = false
            notesFocused = false
        }
    }
}
struct ActiveShiftScreen: View {
    let assignmentName: String
    let shiftStartTime: Date
    var onEndShift: () -> Void
    var onBackToLogin: () -> Void

    @State private var noteText = ""
    @State private var notes: [String] = []

    @State private var showCamera = false
    @State private var latestPhoto: UIImage?
    @State private var photos: [UIImage] = []

    @FocusState private var noteFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // HEADER
                Text("Active Shift")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Assignment")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(assignmentName.isEmpty ? "No assignment entered" : assignmentName)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Text("Started: \(shiftStartTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundColor(.secondary)

                
                // ADD PHOTO
                Button("Add Photo") {
                    showCamera = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.15))
                .cornerRadius(10)
                
                
                // FIELD NOTES
                VStack(alignment: .leading, spacing: 8) {
                    Text("Field Notes")
                        .font(.headline)

                    ZStack(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("Enter note")
                                .foregroundColor(.gray)
                                .padding(.top, 14)
                                .padding(.leading, 10)
                        }

                        TextEditor(text: $noteText)
                            .frame(height: 120)
                            .padding(6)
                            .focused($noteFocused)
                    }
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.5))
                    )
                }

               

                // DIVIDER
                Divider()
                    .frame(height: 1)
                    .background(Color.gray.opacity(0.3))

                // SAVE NOTE
                Button("Save Note") {
                    let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        notes.insert(
                            "\(Date().formatted(date: .omitted, time: .shortened)) - \(trimmed)",
                            at: 0
                        )
                        noteText = ""
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)

                // CURRENT NOTES
                if !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Notes")
                            .font(.headline)

                        ForEach(notes, id: \.self) { note in
                            Text("• \(note)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                // PHOTOS
                if !photos.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photos")
                            .font(.headline)

                        ForEach(Array(photos.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                        }
                    }
                }

                // END SHIFT
                Button("End Shift", action: onEndShift)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                // BACK
                Button("Back to Login", action: onBackToLogin)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black.opacity(0.08))
                    .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Active Shift")
        .navigationBarTitleDisplayMode(.inline)

        // CAMERA
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $latestPhoto)
        }

        // SAVE PHOTO
        .onChange(of: latestPhoto) { _, newValue in
            if let newValue {
                photos.insert(newValue, at: 0)
                latestPhoto = nil
            }
        }

        // KEYBOARD DONE BUTTON
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    noteFocused = false
                }
            }
        }

        .onTapGesture {
            noteFocused = false
        }
    }
}

struct EndShiftScreen: View {
    @State private var showCamera = false
    @State private var endPhoto: UIImage?
    var onClockOut: () -> Void

    var canClockOut: Bool {
        endPhoto != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("End Shift")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ending Odometer Photo")
                        .font(.headline)

                    Button(endPhoto == nil ? "Take Odometer Photo" : "Retake Odometer Photo") {
                        showCamera = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)

                    if let image = endPhoto {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .cornerRadius(12)
                    }
                }

                Button("Clock Out", action: onClockOut)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canClockOut ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!canClockOut)

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $endPhoto)
        }
    }
}
