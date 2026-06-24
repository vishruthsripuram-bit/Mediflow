import SwiftUI
import CoreData

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

struct Settings: View {
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("caregiverEnabled") private var caregiverEnabled: Bool = false
    @AppStorage("caregiverPIN") private var caregiverPIN: String = ""

    @Environment(\.managedObjectContext) private var viewContext

    @State private var showDeleteConfirm  = false
    @State private var showDeletedBanner  = false

    // PIN setup
    @State private var showPINSetup       = false
    @State private var newPIN             = ""
    @State private var confirmPIN         = ""
    @State private var pinMismatch        = false

    // PIN entry to disable
    @State private var showDisablePrompt  = false
    @State private var disablePINEntry    = ""
    @State private var disablePINWrong    = false

    // Caregiver entry
    @State private var showCaregiverEntry = false

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: themeRaw) ?? .system },
            set: { themeRaw = $0.rawValue }
        )
    }

    private func clearAllData() {
        let entities = ["DoseLog", "MyMedication", "Medications"]
        for entity in entities {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let delete = NSBatchDeleteRequest(fetchRequest: fetch)
            delete.resultType = .resultTypeObjectIDs          // ask for deleted IDs back
            if let result = try? viewContext.execute(delete) as? NSBatchDeleteResult,
               let ids = result.result as? [NSManagedObjectID] {
                // Merge the deletions into the live context so @FetchRequests update
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                    into: [viewContext]
                )
            }
        }
        try? viewContext.save()
        showDeletedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showDeletedBanner = false
        }
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Theme
                Section("Theme") {
                    Picker("App Theme", selection: themeBinding) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Caregiver Mode
                Section {
                    if caregiverEnabled {
                        HStack {
                            Label("Caregiver Mode", systemImage: "person.2.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Text("On")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 14))
                        }

                        Button {
                            showCaregiverEntry = true
                        } label: {
                            Label("Open Caregiver View", systemImage: "arrow.right.circle")
                        }

                        Button(role: .destructive) {
                            disablePINEntry = ""
                            disablePINWrong = false
                            showDisablePrompt = true
                        } label: {
                            Label("Disable Caregiver Mode", systemImage: "person.2.slash")
                        }
                    } else {
                        Button {
                            newPIN = ""
                            confirmPIN = ""
                            pinMismatch = false
                            showPINSetup = true
                        } label: {
                            Label("Enable Caregiver Mode", systemImage: "person.2.fill")
                        }
                    }
                } header: {
                    Text("Caregiver")
                } footer: {
                    Text(caregiverEnabled
                         ? "Caregivers can add or remove medications using the PIN you set."
                         : "Allow a caregiver to manage medications behind a PIN.")
                        .foregroundStyle(.secondary)
                }


                // MARK: About
                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                                            Text("Mediflow")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                            Text("Developed by Vishruth Sripuram · 2026")
                                                .font(.system(size: 13))
                                                .foregroundStyle(.secondary)
                                            Text("Released under the MIT License. Permission is granted, free of charge, to any person obtaining a copy of this software to use, copy, modify, merge, publish, distribute, sublicense, or sell copies, subject to the condition that the above copyright notice and permission notice appear in all copies.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 4)
                }

                // MARK: Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Clear All Data")
                        }
                    }
                } footer: {
                    Text("Permanently deletes all medications and dose history. This cannot be undone.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)

            // MARK: PIN Setup sheet
            .sheet(isPresented: $showPINSetup) {
                PINSetupView(
                    newPIN: $newPIN,
                    confirmPIN: $confirmPIN,
                    pinMismatch: $pinMismatch,
                    onSave: {
                        if newPIN.count >= 4, newPIN == confirmPIN {
                            caregiverPIN = newPIN
                            caregiverEnabled = true
                            showPINSetup = false
                        } else {
                            pinMismatch = true
                        }
                    },
                    onCancel: { showPINSetup = false }
                )
            }

            // MARK: Disable confirmation
            .alert("Enter PIN to Disable", isPresented: $showDisablePrompt) {
                SecureField("PIN", text: $disablePINEntry)
                    .keyboardType(.numberPad)
                Button("Confirm", role: .destructive) {
                    if disablePINEntry == caregiverPIN {
                        caregiverEnabled = false
                        caregiverPIN = ""
                    } else {
                        disablePINWrong = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(disablePINWrong ? "Incorrect PIN. Try again." : "Enter your caregiver PIN to disable this feature.")
            }

            // MARK: Caregiver entry
            .fullScreenCover(isPresented: $showCaregiverEntry) {
                CaregiverEntryView(expectedPIN: caregiverPIN)
                    .environment(\.managedObjectContext, viewContext)
            }

            // MARK: Delete confirmation
            .confirmationDialog(
                "Clear All Data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all medications and dose history. This cannot be undone.")
            }

            // MARK: Deleted banner
            .overlay {
                if showDeletedBanner {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                            Text("All data cleared")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.red))
                        .shadow(radius: 6)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(duration: 0.4), value: showDeletedBanner)
                }
            }
        }
    }
}

// MARK: - PIN Setup View

struct PINSetupView: View {
    @Binding var newPIN: String
    @Binding var confirmPIN: String
    @Binding var pinMismatch: Bool
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Enter PIN (min 4 digits)", text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Set Caregiver PIN")
                } footer: {
                    if pinMismatch {
                        Text(newPIN.count < 4
                             ? "PIN must be at least 4 digits."
                             : "PINs do not match. Try again.")
                            .foregroundStyle(.red)
                    } else {
                        Text("The caregiver will need this PIN to access medication management.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Caregiver PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                        .disabled(newPIN.count < 4 || confirmPIN.isEmpty)
                }
            }
        }
    }
}

// MARK: - Caregiver Entry (PIN gate)

struct CaregiverEntryView: View {
    let expectedPIN: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var enteredPIN: String = ""
    @State private var wrongPIN: Bool = false
    @State private var unlocked: Bool = false
    @State private var shake: Bool = false

    var body: some View {
        if unlocked {
            CaregiverView()
                .environment(\.managedObjectContext, viewContext)
        } else {
            NavigationStack {
                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.blue)
                        Text("Caregiver Mode")
                            .font(.system(size: 28, weight: .bold))
                        Text("Enter the PIN to continue")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }

                    // PIN dots
                    HStack(spacing: 18) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i < enteredPIN.count ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 18, height: 18)
                        }
                    }
                    .offset(x: shake ? -10 : 0)
                    .animation(shake ? .default.repeatCount(4, autoreverses: true).speed(4) : .default, value: shake)

                    if wrongPIN {
                        Text("Incorrect PIN")
                            .foregroundStyle(.red)
                            .font(.system(size: 14, weight: .semibold))
                    }

                    // Number pad
                    numberPad

                    Spacer()
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private var numberPad: some View {
        VStack(spacing: 16) {
            ForEach([[1,2,3],[4,5,6],[7,8,9],[0]], id: \.self) { row in
                HStack(spacing: 32) {
                    ForEach(row, id: \.self) { digit in
                        if digit == 0 {
                            // Leading spacer for bottom row
                            Color.clear.frame(width: 72, height: 72)
                            pinButton(digit)
                            pinDeleteButton
                        } else {
                            pinButton(digit)
                        }
                    }
                }
            }
        }
    }

    private func pinButton(_ digit: Int) -> some View {
        Button {
            guard enteredPIN.count < 4 else { return }
            enteredPIN.append(String(digit))
            wrongPIN = false
            if enteredPIN.count == 4 { checkPIN() }
        } label: {
            Text("\(digit)")
                .font(.system(size: 28, weight: .medium))
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }

    private var pinDeleteButton: some View {
        Button {
            if !enteredPIN.isEmpty { enteredPIN.removeLast() }
            wrongPIN = false
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 22))
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }

    private func checkPIN() {
        if enteredPIN == expectedPIN {
            unlocked = true
        } else {
            shake = true
            wrongPIN = true
            enteredPIN = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
        }
    }
}

// MARK: - Caregiver View (restricted)

struct CaregiverView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MyMedication.medication_name, ascending: true)]
    ) private var medications: FetchedResults<MyMedication>

    @State private var medicationToEdit: MyMedication? = nil
    @State private var navigateToAdd = false
    @State private var showExitConfirm = false

    private func delete(_ meds: [MyMedication]) {
        for med in meds { viewContext.delete(med) }
        try? viewContext.save()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    if medications.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "pills")
                                .font(.system(size: 48))
                                .foregroundStyle(.gray.opacity(0.4))
                            Text("No medications added yet")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    } else {
                        Section("Medications") {
                            ForEach(medications) { med in
                                HStack {
                                    Image(systemName: med.medication_icon ?? "pill.fill")
                                        .foregroundStyle(.blue)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(med.medication_name ?? "Unknown")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(med.medication_type ?? "")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.gray)
                                    }
                                    Spacer()
                                    Button {
                                        medicationToEdit = med
                                    } label: {
                                        Image(systemName: "square.and.pencil")
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete([med])
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                delete(indexSet.map { medications[$0] })
                            }
                        }
                    }
                }
                .navigationTitle("Caregiver Mode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Exit") {
                            showExitConfirm = true
                        }
                        .foregroundStyle(.red)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
                .navigationDestination(item: $medicationToEdit) { med in
                    Medication_form(existingMedication: med)
                        .environment(\.managedObjectContext, viewContext)
                }
                .navigationDestination(isPresented: $navigateToAdd) {
                    Medication_form()
                        .environment(\.managedObjectContext, viewContext)
                }
                .confirmationDialog("Exit Caregiver Mode?", isPresented: $showExitConfirm, titleVisibility: .visible) {
                    Button("Exit", role: .destructive) { dismiss() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("You will be returned to the main app.")
                }

                // Add button
                Button {
                    navigateToAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(24)
            }
        }
    }
}

#Preview {
    Settings()
}
