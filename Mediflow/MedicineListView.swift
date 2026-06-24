import SwiftUI
import CoreData
import UserNotifications

struct MedicineListView: View {
    @Binding var currentView: String
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MyMedication.medication_name, ascending: true)]
    ) var medications: FetchedResults<MyMedication>

    @State private var medicationToEdit: MyMedication? = nil
    @State private var navigateToAdd: Bool = false

    private func cancelNotifications(for id: String) {
        var ids = [id]
        ids += (0..<30).map { "\(id)_time_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func delete(_ meds: [MyMedication]) {
        for med in meds {
            if let id = med.medicine_ID {
                cancelNotifications(for: id)
            }
            viewContext.delete(med)
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete medication(s):", error.localizedDescription)
        }
    }

    private func removeExpiredMedications() {
        let today = Calendar.current.startOfDay(for: Date())
        for med in medications {
            guard med.has_end_date, let endDate = med.end_date else { continue }
            let end = Calendar.current.startOfDay(for: endDate)
            if end < today {
                if let id = med.medicine_ID {
                    cancelNotifications(for: id)
                }
                viewContext.delete(med)
            }
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to remove expired medications:", error.localizedDescription)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if medications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "pills")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("No medications yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.gray)
                        Text("Tap + to add your first medication")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Active") {
                            ForEach(medications) { med in
                                HStack {
                                    Image(systemName: med.medication_icon ?? "pill.fill")
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(med.medication_name ?? "Unknown")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(med.medication_type ?? "")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundStyle(.gray)
                                    }
                                    Spacer()
                                    Button {
                                        medicationToEdit = med
                                    } label: {
                                        Image(systemName: "square.and.pencil")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
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
            }
            .navigationTitle("My Medications")
            .toolbar { EditButton() }
            .navigationDestination(item: $medicationToEdit) { med in
                Medication_form(existingMedication: med)
                    .environment(\.managedObjectContext, viewContext)
            }
            .navigationDestination(isPresented: $navigateToAdd) {
                Medication_form()
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                removeExpiredMedications()
            }

            HStack {
                NavigationLink(destination: ScanView()) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
                Spacer()
                Button {
                    navigateToAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }
        }
    }
}
