import SwiftUI
import CoreData
import UserNotifications

struct Medication_form: View {
    var existingMedication: MyMedication? = nil

    @State private var MedicineName: String = ""
    @State private var MedicineIcon: String = "pill"

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
        let ids = (0..<20).map { "\(id)_time_\($0)" }
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
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: makeContent(), trigger: trigger))

        case .daily:
            let comps = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: id, content: makeContent(), trigger: trigger))

        case .multiplePerDay:
            for (index, slot) in multipleTimes.enumerated() {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: slot.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                center.add(UNNotificationRequest(identifier: "\(id)_time_\(index)", content: makeContent(), trigger: trigger))
            }

        case .weekly:
            var comps = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
            comps.weekday = selectedWeekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: id, content: makeContent(), trigger: trigger))

        case .everyNDays:
            let cal = Calendar.current
            for i in 0..<30 {
                guard let fireDate = cal.date(byAdding: .day, value: i * intervalDays, to: composeDate(date: startDate, time: timeOfDay)) else { continue }
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "\(id)_time_\(i)", content: makeContent(), trigger: trigger))
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

    // MARK: - Body

    var body: some View {
        Form {
            Section(header: Text("Medicine Info")) {
                TextField("Name", text: $MedicineName)

                Picker("Icon", selection: $MedicineIcon) {
                    HStack { Image(systemName: "pill"); Text("Pill") }.tag("pill")
                    HStack { Image(systemName: "pill.fill"); Text("Capsule") }.tag("pill.fill")
                    HStack { Image(systemName: "waterbottle"); Text("Liquid") }.tag("waterbottle")
                    HStack { Image(systemName: "circle.lefthalf.filled"); Text("Chewable") }.tag("circle.lefthalf.filled")
                    HStack { Image(systemName: "capsule.on.capsule"); Text("Gummy") }.tag("capsule.on.capsule")
                    HStack { Image(systemName: "syringe"); Text("Injection") }.tag("syringe")
                }

                Picker("Type", selection: $selectedMedicineType) {
                    ForEach(MedicineType.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Schedule")) {
                DisclosureGroup(isExpanded: $isFrequencyExpanded) {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(Frequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 150)
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
                    target.medication_name = MedicineName
                    target.medication_icon = MedicineIcon
                    target.medication_type = selectedMedicineType.rawValue
                    target.frequency = frequencyAsInt
                    target.interval_days = Int16(intervalDays)
                    target.start_date = startDate
                    target.time_of_day = timeOfDay
                    target.selected_days = Int16(selectedWeekday)
                    target.end_date = hasEndDate ? endDate : nil
                    target.has_end_date = hasEndDate
                    if target.medicine_ID == nil {
                        target.medicine_ID = UUID().uuidString
                    }
                    do {
                        try viewContext.save()
                        scheduleNotifications(for: MedicineName, id: target.medicine_ID!)
                        showSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                        }
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
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
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
        .onAppear {
            if let med = existingMedication {
                MedicineName = med.medication_name ?? ""
                MedicineIcon = med.medication_icon ?? "pill"
                selectedMedicineType = MedicineType(rawValue: med.medication_type ?? "") ?? .vitamin
                startDate = med.start_date ?? .now
                timeOfDay = med.time_of_day ?? .now
                intervalDays = Int(med.interval_days)
                selectedWeekday = Int(med.selected_days)
                hasEndDate = med.has_end_date
                endDate = med.end_date ?? .now
                switch med.frequency {
                case 0: frequency = .once
                case 1: frequency = .daily
                case 2: frequency = .multiplePerDay
                case 3: frequency = .weekly
                case 4: frequency = .everyNDays
                default: frequency = .once
                }
            }
        }
    }
}

#Preview {
    Medication_form()
}

private func weekdayName(from value: Int) -> String {
    switch value {
    case 1: return "Sunday"
    case 2: return "Monday"
    case 3: return "Tuesday"
    case 4: return "Wednesday"
    case 5: return "Thursday"
    case 6: return "Friday"
    case 7: return "Saturday"
    default: return "Unknown"
    }
}
