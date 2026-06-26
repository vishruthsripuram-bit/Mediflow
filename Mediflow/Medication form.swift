import SwiftUI
import CoreData
import UserNotifications

// MARK: - Shared helper: encode/decode multiple times

func encodeMultipleTimes(_ times: [Date]) -> String {
    times.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
}

func decodeMultipleTimes(_ string: String) -> [Date] {
    string.split(separator: ",").compactMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }
}

struct Medication_form: View {
    var existingMedication: MyMedication? = nil
    var scannedData: ScannedMedication? = nil

    @State private var MedicineName: String = ""
    @State private var MedicineIcon: String = "pill"
    @State private var MedicineDose: String = ""
    @State private var MedicineNotes: String = ""
    @State private var MedicineColor: String = "blue"

    struct DoseTime: Identifiable, Hashable {
        let id: UUID
        var date: Date
        init(id: UUID = UUID(), date: Date) {
            self.id = id
            self.date = date
        }
    }

    enum MedicineType: String, CaseIterable, Identifiable {
        case antibiotic = "Antibiotic"
        case antiviral = "Antiviral"
        case antifungal = "Antifungal"
        case analgesic = "Pain reliever"
        case antipyretic = "Fever reducer"
        case antihistamine = "Antihistamine"
        case vitamin = "Vitamin"
        case supplement = "Supplement"
        var id: String { rawValue }
    }

    @State private var selectedMedicineType: MedicineType = .vitamin

    enum Frequency: String, CaseIterable, Identifiable {
        case once = "Once"
        case daily = "Daily"
        case multiplePerDay = "Multiple times a day"
        case weekly = "Weekly"
        case everyNDays = "Every N days"
        var id: String { rawValue }
    }

    @State private var frequency: Frequency = .once
    @State private var intervalDays: Int = 2
    @State private var startDate: Date = .now
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = .now
    @State private var timeOfDay: Date = .now
    @State private var multipleTimes: [DoseTime] = [DoseTime(date: Date())]
    @State private var selectedWeekday: Int = 2

    @State private var isFrequencyExpanded: Bool = false
    @State private var isStartDateExpanded: Bool = false
    @State private var isEndDateExpanded: Bool = false
    @State private var isTimeExpanded: Bool = false
    @State private var isMultipleTimesExpanded: Bool = false
    @State private var isWeekdayExpanded: Bool = false
    @State private var isIntervalExpanded: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showTimePrompt: Bool = false

    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss

    var frequencyAsInt: Int16 {
        switch frequency {
        case .once: return 0
        case .daily: return 1
        case .multiplePerDay: return 2
        case .weekly: return 3
        case .everyNDays: return 4
        }
    }

    // MARK: - Notifications

    func cancelNotifications(for id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        let ids = (0..<30).map { "\(id)_time_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func scheduleNotifications(for name: String, id: String) {
        cancelNotifications(for: id)
        let center = UNUserNotificationCenter.current()

        func makeContent() -> UNMutableNotificationContent {
            let c = UNMutableNotificationContent()
            c.title = "Time to take your medication"
            c.body = "Take your \(name) now"
            c.sound = .default
            return c
        }

        switch frequency {
        case .once:
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: composeDate(date: startDate, time: timeOfDay))
            center.add(UNNotificationRequest(identifier: id, content: makeContent(),
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))

        case .daily:
            let comps = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
            center.add(UNNotificationRequest(identifier: id, content: makeContent(),
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))

        case .multiplePerDay:
            for (index, slot) in multipleTimes.enumerated() {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: slot.date)
                center.add(UNNotificationRequest(identifier: "\(id)_time_\(index)", content: makeContent(),
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
            }

        case .weekly:
            var comps = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
            comps.weekday = selectedWeekday
            center.add(UNNotificationRequest(identifier: id, content: makeContent(),
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))

        case .everyNDays:
            let cal = Calendar.current
            for i in 0..<30 {
                guard let fireDate = cal.date(byAdding: .day, value: i * intervalDays,
                                              to: composeDate(date: startDate, time: timeOfDay)) else { continue }
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                center.add(UNNotificationRequest(identifier: "\(id)_time_\(i)", content: makeContent(),
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    func composeDate(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        comps.hour = t.hour
        comps.minute = t.minute
        return cal.date(from: comps) ?? date
    }

    private func evenlySpacedTimes(count: Int) -> [DoseTime] {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        guard count > 1 else {
            return [DoseTime(date: cal.date(byAdding: .hour, value: 8, to: base) ?? base)]
        }
        let startHour = 8, endHour = 22, span = endHour - startHour
        return (0..<count).map { i in
            let hour = startHour + (span * i) / (count - 1)
            return DoseTime(date: cal.date(byAdding: .hour, value: hour, to: base) ?? base)
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            if scannedData != nil {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.viewfinder").foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pre-filled from prescription")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Review and adjust any details before saving.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Medicine Info")) {
                TextField("Name", text: $MedicineName)
                TextField("Dose (e.g. 500mg)", text: $MedicineDose)
                TextField("Notes (e.g. after dinner)", text: $MedicineNotes)
                // Color tag picker
                HStack {
                    Text("Color Tag")
                        .font(.system(size: 16))
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(["red", "orange", "yellow", "green", "blue", "purple", "pink"], id: \.self) { colorName in
                            Circle()
                                .fill(colorFromName(colorName))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: MedicineColor == colorName ? 2.5 : 0)
                                        .padding(2)
                                )
                                .onTapGesture { MedicineColor = colorName }
                        }
                    }
                }

                Picker("Icon", selection: $MedicineIcon) {
                    HStack { Image(systemName: "pill");               Text("Pill") }.tag("pill")
                    HStack { Image(systemName: "pill.fill");          Text("Capsule") }.tag("pill.fill")
                    HStack { Image(systemName: "waterbottle");        Text("Liquid") }.tag("waterbottle")
                    HStack { Image(systemName: "circle.lefthalf.filled"); Text("Chewable") }.tag("circle.lefthalf.filled")
                    HStack { Image(systemName: "capsule.on.capsule"); Text("Gummy") }.tag("capsule.on.capsule")
                    HStack { Image(systemName: "syringe");            Text("Injection") }.tag("syringe")
                }

                Picker("Type", selection: $selectedMedicineType) {
                    ForEach(MedicineType.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Schedule")) {
                DisclosureGroup(isExpanded: $isFrequencyExpanded) {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(Frequency.allCases) { freq in Text(freq.rawValue).tag(freq) }
                    }
                    .pickerStyle(.wheel).frame(maxHeight: 150)
                } label: {
                    HStack {
                        Text("Frequency")
                        Spacer()
                        Text(frequency.rawValue).foregroundStyle(.secondary)
                    }
                }

                DisclosureGroup(isExpanded: $isStartDateExpanded) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                } label: {
                    HStack {
                        Text("Start Date")
                        Spacer()
                        Text(startDate, style: .date).foregroundStyle(.secondary)
                    }
                }

                DisclosureGroup(isExpanded: $isEndDateExpanded) {
                    Toggle("Set End Date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: [.date])
                            .datePickerStyle(.compact)
                    }
                } label: {
                    HStack {
                        Text("End Date")
                        Spacer()
                        if hasEndDate {
                            Text(endDate, style: .date).foregroundStyle(.secondary)
                        } else {
                            Text("None").foregroundStyle(.secondary)
                        }
                    }
                }

                switch frequency {
                case .once:
                    DisclosureGroup(isExpanded: $isTimeExpanded) {
                        DatePicker("Time", selection: $timeOfDay, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel).labelsHidden().frame(maxHeight: 150)
                    } label: {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text(timeOfDay.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                        }
                    }

                case .daily:
                    DisclosureGroup(isExpanded: $isTimeExpanded) {
                        DatePicker("Time each day", selection: $timeOfDay, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel).labelsHidden().frame(maxHeight: 150)
                    } label: {
                        HStack {
                            Text("Time each day")
                            Spacer()
                            Text(timeOfDay.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                        }
                    }

                case .multiplePerDay:
                    DisclosureGroup(isExpanded: $isMultipleTimesExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(multipleTimes.indices, id: \.self) { index in
                                HStack(alignment: .center, spacing: 12) {
                                    Text("Time \(index + 1)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    DatePicker("", selection: Binding<Date>(
                                        get: { multipleTimes[index].date },
                                        set: { multipleTimes[index].date = $0 }
                                    ), displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact).labelsHidden()
                                    Button(role: .destructive) {
                                        if multipleTimes.indices.contains(index) {
                                            multipleTimes.remove(at: index)
                                            if multipleTimes.isEmpty {
                                                multipleTimes.append(DoseTime(date: Date()))
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "trash").foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            Button {
                                multipleTimes.append(DoseTime(date: multipleTimes.last?.date ?? Date()))
                            } label: {
                                Label("Add time", systemImage: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack {
                            Text("Times")
                            Spacer()
                            Text("\(multipleTimes.count) time\(multipleTimes.count == 1 ? "" : "s")").foregroundStyle(.secondary)
                        }
                    }

                case .weekly:
                    DisclosureGroup(isExpanded: $isWeekdayExpanded) {
                        Picker("Weekday", selection: $selectedWeekday) {
                            Text("Sunday").tag(1); Text("Monday").tag(2); Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4); Text("Thursday").tag(5)
                            Text("Friday").tag(6); Text("Saturday").tag(7)
                        }
                        .pickerStyle(.wheel).frame(maxHeight: 150)
                    } label: {
                        HStack {
                            Text("Weekday")
                            Spacer()
                            Text(weekdayName(from: selectedWeekday)).foregroundStyle(.secondary)
                        }
                    }
                    DisclosureGroup(isExpanded: $isTimeExpanded) {
                        DatePicker("Time", selection: $timeOfDay, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel).labelsHidden().frame(maxHeight: 150)
                    } label: {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text(timeOfDay.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                        }
                    }

                case .everyNDays:
                    DisclosureGroup(isExpanded: $isIntervalExpanded) {
                        HStack {
                            Text("Every")
                            Picker("Interval Days", selection: $intervalDays) {
                                ForEach(1...30, id: \.self) { n in Text("\(n)").tag(n) }
                            }
                            .pickerStyle(.wheel).frame(maxHeight: 120)
                            Text("day\(intervalDays == 1 ? "" : "s")")
                        }
                    } label: {
                        HStack {
                            Text("Interval")
                            Spacer()
                            Text("Every \(intervalDays) day\(intervalDays == 1 ? "" : "s")").foregroundStyle(.secondary)
                        }
                    }
                    DisclosureGroup(isExpanded: $isTimeExpanded) {
                        DatePicker("Time", selection: $timeOfDay, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel).labelsHidden().frame(maxHeight: 150)
                    } label: {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text(timeOfDay.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(existingMedication == nil ? "Add Medication" : "Edit Medication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    let target = existingMedication ?? MyMedication(context: viewContext)
                    target.medication_name  = MedicineName
                    target.medication_icon  = MedicineIcon
                    target.medication_type  = selectedMedicineType.rawValue
                    target.dose             = MedicineDose
                    target.frequency        = frequencyAsInt
                    target.interval_days    = Int16(intervalDays)
                    target.start_date       = startDate
                    target.time_of_day      = timeOfDay
                    target.selected_days    = Int16(selectedWeekday)
                    target.end_date         = hasEndDate ? endDate : nil
                    target.has_end_date     = hasEndDate
                    target.notes            = MedicineNotes.isEmpty ? nil : MedicineNotes
                    target.color_tag        = MedicineColor
                    // Save multiple times to Core Data
                    if frequency == .multiplePerDay {
                        target.multiple_times = encodeMultipleTimes(multipleTimes.map { $0.date })
                    } else {
                        target.multiple_times = nil
                    }
                    if target.medicine_ID == nil {
                        target.medicine_ID = UUID().uuidString
                    }
                    do {
                        try viewContext.save()
                        scheduleNotifications(for: MedicineName, id: target.medicine_ID!)
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                    } catch {
                        print("Save failed: \(error)")
                    }
                }
                .disabled(MedicineName.isEmpty)
            }
        }
        .overlay {
            if showSuccess {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.white)
                        Text("Saved")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                .animation(.spring(duration: 0.3), value: showSuccess)
            }
        }
        .sheet(isPresented: $showTimePrompt) {
            TimePromptView(
                frequency: frequency,
                timesPerDay: scannedData?.timesPerDay ?? 1,
                timeOfDay: $timeOfDay,
                multipleTimes: $multipleTimes
            )
        }
        .onAppear {
            if let med = existingMedication {
                MedicineName         = med.medication_name ?? ""
                MedicineIcon         = med.medication_icon ?? "pill"
                MedicineDose         = med.dose ?? ""
                MedicineNotes        = med.notes ?? ""
                MedicineColor        = med.color_tag ?? "blue"
                selectedMedicineType = MedicineType(rawValue: med.medication_type ?? "") ?? .vitamin
                startDate            = med.start_date ?? .now
                timeOfDay            = med.time_of_day ?? .now
                intervalDays         = Int(med.interval_days)
                selectedWeekday      = Int(med.selected_days)
                hasEndDate           = med.has_end_date
                endDate              = med.end_date ?? .now
                switch med.frequency {
                case 0: frequency = .once
                case 1: frequency = .daily
                case 2: frequency = .multiplePerDay
                case 3: frequency = .weekly
                case 4: frequency = .everyNDays
                default: frequency = .once
                }
                // Restore saved multiple times
                if med.frequency == 2, let stored = med.multiple_times, !stored.isEmpty {
                    multipleTimes = decodeMultipleTimes(stored).map { DoseTime(date: $0) }
                }
            } else if let scan = scannedData {
                MedicineName = scan.name
                MedicineDose = scan.dose
                if !scan.type.isEmpty {
                    selectedMedicineType = MedicineType(rawValue: scan.type) ?? .vitamin
                }
                switch scan.frequency {
                case 0: frequency = .once
                case 1: frequency = .daily
                case 2: frequency = .multiplePerDay
                case 3: frequency = .weekly
                case 4: frequency = .everyNDays
                default: frequency = .daily
                }
                intervalDays = Int(scan.intervalDays)
                hasEndDate   = scan.hasEndDate
                if scan.hasEndDate, let days = scan.durationDays,
                   let end = Calendar.current.date(byAdding: .day, value: days, to: startDate) {
                    endDate = end
                }
                if scan.frequency == 2 && scan.timesPerDay > 1 {
                    multipleTimes = evenlySpacedTimes(count: scan.timesPerDay)
                }
                if scan.frequency != 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showTimePrompt = true
                    }
                }
            }
        }
    }
}

// MARK: - Time Prompt Sheet

struct TimePromptView: View {
    let frequency: Medication_form.Frequency
    let timesPerDay: Int
    @Binding var timeOfDay: Date
    @Binding var multipleTimes: [Medication_form.DoseTime]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill").foregroundStyle(.blue)
                        Text("Your prescription specifies how often to take this medication. Please set the time(s) you'd like to be reminded.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if frequency == .multiplePerDay {
                    Section("Dose Times") {
                        ForEach(multipleTimes.indices, id: \.self) { index in
                            HStack {
                                Text("Dose \(index + 1)").font(.system(size: 15, weight: .medium))
                                Spacer()
                                DatePicker("", selection: Binding(
                                    get: { multipleTimes[index].date },
                                    set: { multipleTimes[index].date = $0 }
                                ), displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                            }
                        }
                    }
                } else {
                    Section("Reminder Time") {
                        DatePicker("Time", selection: $timeOfDay, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel).labelsHidden().frame(maxHeight: 150)
                    }
                }
            }
            .navigationTitle("Set Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview { Medication_form() }

func colorFromName(_ name: String) -> Color {
    switch name {
    case "red":    return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "green":  return .green
    case "blue":   return .blue
    case "purple": return .purple
    case "pink":   return .pink
    default:       return .blue
    }
}

private func weekdayName(from value: Int) -> String {
    switch value {
    case 1: return "Sunday";  case 2: return "Monday";  case 3: return "Tuesday"
    case 4: return "Wednesday"; case 5: return "Thursday"; case 6: return "Friday"
    case 7: return "Saturday"; default: return "Unknown"
    }
}
