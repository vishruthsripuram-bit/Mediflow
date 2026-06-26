import SwiftUI
import CoreData

struct ContentView: View {
    @State private var currentView = "home"
    @State private var showNotes: Bool = false
    @State private var notesForMed: MyMedication? = nil
    @Environment(\.managedObjectContext) var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MyMedication.time_of_day, ascending: true)]
    ) var medications: FetchedResults<MyMedication>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DoseLog.scheduled_time, ascending: false)]
    ) var doseLogs: FetchedResults<DoseLog>

    private var cal: Calendar { Calendar.current }

    private func todayAt(_ time: Date) -> Date {
        var comps = cal.dateComponents([.year, .month, .day], from: cal.startOfDay(for: Date()))
        let t = cal.dateComponents([.hour, .minute], from: time)
        comps.hour = t.hour
        comps.minute = t.minute
        return cal.date(from: comps) ?? Date()
    }

    private func findLog(medicineID: String, scheduled: Date) -> DoseLog? {
        let start = cal.date(byAdding: .minute, value: -1, to: scheduled) ?? scheduled
        let end   = cal.date(byAdding: .minute, value: 1,  to: scheduled) ?? scheduled
        return doseLogs.first {
            $0.medicine_ID == medicineID &&
            ($0.scheduled_time ?? .distantPast) >= start &&
            ($0.scheduled_time ?? .distantPast) <= end
        }
    }

    /// Expand a medication into all its scheduled times for today
    private func scheduledTimesToday(for med: MyMedication) -> [Date] {
        switch med.frequency {
        case 2: // multiplePerDay — use stored times
            if let stored = med.multiple_times, !stored.isEmpty {
                return decodeMultipleTimes(stored).map { todayAt($0) }
            }
            // fallback: single time_of_day
            if let t = med.time_of_day { return [todayAt(t)] }
            return []
        default:
            if let t = med.time_of_day { return [todayAt(t)] }
            return []
        }
    }

    /// All individual dose slots for today that are not yet taken or skipped
    private var pendingDoses: [(med: MyMedication, scheduledTime: Date)] {
        var result: [(MyMedication, Date)] = []
        for med in medications {
            for scheduled in scheduledTimesToday(for: med) {
                if let log = findLog(medicineID: med.medicine_ID ?? "", scheduled: scheduled) {
                    if log.status == "taken" || log.status == "skipped" { continue }
                }
                result.append((med, scheduled))
            }
        }
        return result.sorted { $0.1 < $1.1 }
    }

    private var nextUpDose: (med: MyMedication, scheduledTime: Date)? {
        pendingDoses.first
    }

    private func logDose(med: MyMedication, scheduled: Date, status: String) {
        guard let id = med.medicine_ID else { return }
        let log = findLog(medicineID: id, scheduled: scheduled) ?? DoseLog(context: viewContext)
        log.log_ID          = log.log_ID ?? UUID().uuidString
        log.medicine_ID     = id
        log.medication_name = med.medication_name
        log.scheduled_time  = scheduled
        log.actual_time     = Date()
        log.status          = status
        do { try viewContext.save() } catch { print("Failed to log dose: \(error)") }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack {
                        HStack {
                            Text("Medications")
                                .font(.system(size: 38, weight: .bold))
                                .padding(.top)
                            Spacer()
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 20)

                        HStack {
                            Text("Next Up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, -4)
                    }

                    // MARK: Next Up card
                    if let (med, scheduledTime) = nextUpDose {
                        let existingStatus = findLog(medicineID: med.medicine_ID ?? "", scheduled: scheduledTime)?.status

                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: med.medication_icon ?? "pill.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.white)
                                        .frame(width: 55, height: 55)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(colorFromName(med.color_tag ?? "blue"))
                                        )
                                    VStack(alignment: .leading) {
                                        Text(med.medication_name ?? "Unknown")
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Text(med.medication_type ?? "")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.gray)
                                    }
                                    Spacer()
                                }

                                Spacer()

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Next Dose:")
                                            .font(.system(size: 18, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .foregroundStyle(.gray)
                                        Text(scheduledTime.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundStyle(.primary)
                                    }
                                    Spacer()

                                    if let status = existingStatus {
                                        VStack(spacing: 6) {
                                            Image(systemName: status == "taken" ? "checkmark.circle.fill" : "forward.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(status == "taken" ? .green : .orange)
                                            Text(status == "taken" ? "Taken" : "Skipped")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        VStack(spacing: 8) {
                                            Button {
                                                logDose(med: med, scheduled: scheduledTime, status: "taken")
                                            } label: {
                                                Text("Taken")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 120, height: 45)
                                                    .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color.blue))
                                            }
                                            Button {
                                                logDose(med: med, scheduled: scheduledTime, status: "skipped")
                                            } label: {
                                                Text("Skip")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 120, height: 45)
                                                    .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color.orange))
                                            }
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 200)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
                        .padding(.horizontal)
                        .animation(.spring(duration: 0.4), value: "\(med.medicine_ID ?? "")-\(scheduledTime.timeIntervalSince1970)")

                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(medications.isEmpty ? "No medications yet" : "All doses taken today 🎉")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.gray)
                                Text(medications.isEmpty ? "Tap the pill icon below to add one" : "Great job! Check back tomorrow.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 200)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
                        .padding(.horizontal)
                    }

                    // MARK: Up Next list — all remaining pending doses after the first
                    if pendingDoses.count > 1 {
                        VStack {
                            HStack {
                                Text("Up Next")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.gray)
                                Spacer()
                            }
                            .padding(.top, 12)
                            .padding(.bottom, -4)
                            .padding(.horizontal)

                            VStack {
                                ForEach(Array(pendingDoses.dropFirst().enumerated()), id: \.offset) { index, pair in
                                    if index > 0 { Divider().padding(.vertical, 4) }
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(colorFromName(pair.med.color_tag ?? "blue"))
                                        VStack(alignment: .leading) {
                                            Text(pair.med.medication_name ?? "Unknown")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(.primary)
                                            Text(pair.med.medication_type ?? "")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text(pair.scheduledTime.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 18)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 100)
                }

                // MARK: Nav bar
                VStack {
                    HStack {
                        HStack {
                            NavigationLink(destination: MedicationOverviewView()
                                .environment(\.managedObjectContext, viewContext)) {
                                Circle()
                                    .fill(Color(.systemGray4).opacity(0.5))
                                    .frame(width: 45, height: 45)
                                    .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                    .overlay(Image(systemName: "chart.pie").foregroundStyle(.indigo))
                            }
                            NavigationLink(destination: MedicineListView(currentView: $currentView)
                                .environment(\.managedObjectContext, viewContext)) {
                                Circle()
                                    .fill(Color(.systemGray4).opacity(0.5))
                                    .frame(width: 45, height: 45)
                                    .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                    .overlay(Image(systemName: "pill").foregroundStyle(.pink))
                            }
                        }
                        Spacer()
                        NavigationLink(destination: Settings()
                            .environment(\.managedObjectContext, viewContext)) {
                            Circle()
                                .fill(Color(.systemGray4).opacity(0.5))
                                .frame(width: 45, height: 45)
                                .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                .overlay(Image(systemName: "gear").foregroundStyle(.gray))
                        }
                    }
                    .padding(.horizontal, 30)
                }
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showNotes) {
                if let med = notesForMed {
                    NotesSheetView(med: med)
                }
            }
        }
    }
}

#Preview { ContentView() }

// MARK: - Notes Sheet

struct NotesSheetView: View {
    let med: MyMedication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: 14) {
                    Image(systemName: med.medication_icon ?? "pill.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(med.medication_name ?? "Medication")
                            .font(.system(size: 20, weight: .bold))
                        if let dose = med.dose, !dose.isEmpty {
                            Text(dose)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Notes", systemImage: "note.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    Text(med.notes ?? "")
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
