import SwiftUI
import CoreData

fileprivate enum DoseStatus: String {
    case taken, skipped, missed, upcoming
}

fileprivate struct DoseOccurrence: Identifiable {
    let id = UUID()
    let med: MyMedication?
    let medicationName: String
    let medicationType: String
    let medicationIcon: String
    let scheduled: Date
    var status: DoseStatus
}

fileprivate enum ViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
}

struct MedicationOverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \MyMedication.medication_name, ascending: true)])
    private var medications: FetchedResults<MyMedication>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DoseLog.scheduled_time, ascending: false)])
    private var doseLogs: FetchedResults<DoseLog>

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var occurrences: [DoseOccurrence] = []
    @State private var viewMode: ViewMode = .day
    @State private var weekOffset: Int = 0

    private var cal: Calendar { Calendar.current }

    private var weekStart: Date {
        let base = cal.startOfDay(for: Date())
        guard let offsetBase = cal.date(byAdding: .weekOfYear, value: weekOffset, to: base) else { return base }
        let weekday = cal.component(.weekday, from: offsetBase)
        let daysToMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysToMonday, to: offsetBase) ?? offsetBase
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var headerTitle: String {
        if cal.isDateInToday(selectedDate) { return "Today" }
        if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
        if cal.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        return selectedDate.formatted(.dateTime.weekday(.wide).day().month())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                viewModeToggle
                weekSelector
                if viewMode == .day {
                    ringSummaryCard
                    timelineCard
                } else {
                    weekSummaryCard
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Overview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { rebuildOccurrences() }
        .onChange(of: medications.count) { _, _ in rebuildOccurrences() }
        .onChange(of: selectedDate) { _, _ in rebuildOccurrences() }
        .onChange(of: doseLogs.count) { _, _ in rebuildOccurrences() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Medication")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
                Text(headerTitle)
                    .font(.system(size: 36, weight: .bold))
                    .animation(.none, value: headerTitle)
            }
            Spacer()
        }
    }

    // MARK: - View mode toggle

    private var viewModeToggle: some View {
        Picker("View", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Week selector

    private var weekSelector: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    weekOffset -= 1
                    if let newDate = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                        selectedDate = cal.startOfDay(for: newDate)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text("\(weekStart.formatted(.dateTime.day().month())) – \(weekDays.last?.formatted(.dateTime.day().month().year()) ?? "")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    weekOffset += 1
                    if let newDate = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
                        selectedDate = cal.startOfDay(for: newDate)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                    let isToday = cal.isDateInToday(day)
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.gray)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(isSelected ? Color.blue : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = cal.startOfDay(for: day)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Day view: ring summary

    private var ringSummaryCard: some View {
        let takenCount = occurrences.filter { $0.status == .taken }.count
        let missedCount = occurrences.filter { $0.status == .missed }.count
        let skippedCount = occurrences.filter { $0.status == .skipped }.count
        let upcomingCount = occurrences.filter { $0.status == .upcoming }.count
        let total = max(occurrences.count, 1)
        let progress = Double(takenCount) / Double(total)

        return HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.gray)
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            .frame(width: 70, height: 70)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 70, height: 70)
                        VStack(spacing: 0) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 14, weight: .bold))
                            Text("taken")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(takenCount) taken", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Label("\(missedCount) missed", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                        Label("\(skippedCount) skipped", systemImage: "forward.circle.fill").foregroundStyle(.orange)
                        Label("\(upcomingCount) upcoming", systemImage: "clock.fill").foregroundStyle(.blue)
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Day view: timeline

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.gray)

            // Past logs for deleted medications
            let historicalLogs = historicalOnlyLogs(for: selectedDate)

            if occurrences.isEmpty && historicalLogs.isEmpty {
                Text("No doses scheduled for this day")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(occurrences) { occ in
                        timelineRow(for: occ)
                        if occ.id != occurrences.last?.id || !historicalLogs.isEmpty {
                            Divider().padding(.leading, 44)
                        }
                    }
                    ForEach(historicalLogs) { log in
                        historicalRow(for: log)
                        if log.id != historicalLogs.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func timelineRow(for occ: DoseOccurrence) -> some View {
        let color: Color = {
            switch occ.status {
            case .taken: return .green
            case .missed: return .red
            case .skipped: return .orange
            case .upcoming: return .blue
            }
        }()

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: iconName(for: occ.status)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(occ.medicationName)
                    .font(.system(size: 16, weight: .semibold))
                HStack(spacing: 8) {
                    Text(occ.scheduled.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.gray)
                        .font(.system(size: 13, weight: .medium))
                    Text(occ.medicationType)
                        .foregroundStyle(.gray)
                        .font(.system(size: 12))
                }
            }
            Spacer()
            if occ.status == .upcoming || occ.status == .missed {
                Button { mark(occurrence: occ, as: .taken) } label: {
                    Text("Taken")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
                }
                Button { mark(occurrence: occ, as: .skipped) } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
                }
            }
        }
        .padding(.vertical, 10)
    }

    // Row for logs whose medication has been deleted
    private func historicalRow(for log: DoseLog) -> some View {
        let status = DoseStatus(rawValue: log.status ?? "") ?? .missed
        let color: Color = {
            switch status {
            case .taken: return .green
            case .missed: return .red
            case .skipped: return .orange
            case .upcoming: return .blue
            }
        }()

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: iconName(for: status)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(log.medication_name ?? log.medicine_ID ?? "Deleted medication")
                        .font(.system(size: 16, weight: .semibold))
                    Text("(removed)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text((log.scheduled_time ?? log.actual_time ?? Date()).formatted(date: .omitted, time: .shortened))
                    .foregroundStyle(.gray)
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Week view

    private var weekSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly adherence")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.gray)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    let dayOccs = occurrencesFor(day: day)
                    let historicalCount = historicalOnlyLogs(for: day).count
                    let totalCount = dayOccs.count + historicalCount
                    let total = max(totalCount, 1)
                    let taken = dayOccs.filter { $0.status == .taken }.count +
                                historicalOnlyLogs(for: day).filter { $0.status == "taken" }.count
                    let ratio = Double(taken) / Double(total)
                    let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                    let isFuture = day > Date()

                    VStack(spacing: 6) {
                        Text("\(taken)/\(totalCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 32, height: 80)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(isFuture ? Color.gray.opacity(0.2) : taken == totalCount && taken > 0 ? Color.green : Color.blue)
                                .frame(width: 32, height: max(4, 80 * ratio))
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )

                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? .blue : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selectedDate = cal.startOfDay(for: day)
                        viewMode = .day
                    }
                }
            }

            let weekOccs = weekDays.flatMap { occurrencesFor(day: $0) }
            let weekHistorical = weekDays.flatMap { historicalOnlyLogs(for: $0) }
            let weekTaken = weekOccs.filter { $0.status == .taken }.count +
                            weekHistorical.filter { $0.status == "taken" }.count
            let weekMissed = weekOccs.filter { $0.status == .missed }.count +
                             weekHistorical.filter { $0.status == "missed" }.count
            let weekSkipped = weekOccs.filter { $0.status == .skipped }.count +
                              weekHistorical.filter { $0.status == "skipped" }.count

            Divider()

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(weekTaken)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.green)
                    Text("Taken")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(weekMissed)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.red)
                    Text("Missed")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(weekSkipped)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("Skipped")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Tap a bar to see that day")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Helpers

    private func iconName(for status: DoseStatus) -> String {
        switch status {
        case .taken: return "checkmark"
        case .missed: return "xmark"
        case .skipped: return "forward.fill"
        case .upcoming: return "clock"
        }
    }

    /// Returns logs for the given day whose medicine_ID no longer exists in MyMedication
    private func historicalOnlyLogs(for day: Date) -> [DoseLog] {
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let activeMedIDs = Set(medications.compactMap { $0.medicine_ID })
        return doseLogs.filter { log in
            guard let medID = log.medicine_ID,
                  !activeMedIDs.contains(medID),
                  let t = log.scheduled_time ?? log.actual_time
            else { return false }
            return t >= dayStart && t < dayEnd
        }
    }

    private func occurrencesFor(day: Date) -> [DoseOccurrence] {
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        var items: [DoseOccurrence] = []

        for med in medications {
            guard let medID = med.medicine_ID else { continue }
            let start = med.start_date ?? dayStart
            let hasEnd = med.has_end_date
            let end = med.end_date ?? dayEnd
            guard dayStart >= cal.startOfDay(for: start) else { continue }
            if hasEnd, dayStart > cal.startOfDay(for: end) { continue }

            let name = med.medication_name ?? "Unknown"
            let type = med.medication_type ?? ""
            let icon = med.medication_icon ?? "pill.fill"

            switch med.frequency {
            case 0:
                if let t = med.time_of_day, cal.isDate(t, inSameDayAs: dayStart) {
                    items.append(DoseOccurrence(med: med, medicationName: name, medicationType: type, medicationIcon: icon, scheduled: t, status: statusFor(medicineID: medID, scheduled: t)))
                }
            case 1:
                if let t = med.time_of_day, let s = combineDate(dayStart, time: t) {
                    items.append(DoseOccurrence(med: med, medicationName: name, medicationType: type, medicationIcon: icon, scheduled: s, status: statusFor(medicineID: medID, scheduled: s)))
                }
            case 2:
                if let t = med.time_of_day, let s = combineDate(dayStart, time: t) {
                    items.append(DoseOccurrence(med: med, medicationName: name, medicationType: type, medicationIcon: icon, scheduled: s, status: statusFor(medicineID: medID, scheduled: s)))
                }
            case 3:
                if let t = med.time_of_day,
                   cal.component(.weekday, from: dayStart) == Int(med.selected_days),
                   let s = combineDate(dayStart, time: t) {
                    items.append(DoseOccurrence(med: med, medicationName: name, medicationType: type, medicationIcon: icon, scheduled: s, status: statusFor(medicineID: medID, scheduled: s)))
                }
            case 4:
                if let base = med.start_date, let t = med.time_of_day {
                    let n = max(Int(med.interval_days), 1)
                    let distance = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: dayStart).day ?? 0
                    if distance >= 0, distance % n == 0, let s = combineDate(dayStart, time: t) {
                        items.append(DoseOccurrence(med: med, medicationName: name, medicationType: type, medicationIcon: icon, scheduled: s, status: statusFor(medicineID: medID, scheduled: s)))
                    }
                }
            default: break
            }
        }
        return items.sorted { $0.scheduled < $1.scheduled }
    }

    private func rebuildOccurrences() {
        occurrences = occurrencesFor(day: selectedDate)
    }

    private func combineDate(_ date: Date, time: Date) -> Date? {
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        comps.hour = t.hour
        comps.minute = t.minute
        return cal.date(from: comps)
    }

    private func findLog(medicineID: String, scheduled: Date) -> DoseLog? {
        let start = cal.date(byAdding: .minute, value: -1, to: scheduled) ?? scheduled
        let end = cal.date(byAdding: .minute, value: 1, to: scheduled) ?? scheduled
        return doseLogs.first {
            $0.medicine_ID == medicineID &&
            ($0.scheduled_time ?? .distantPast) >= start &&
            ($0.scheduled_time ?? .distantPast) <= end
        }
    }

    private func statusFor(medicineID: String, scheduled: Date) -> DoseStatus {
        if let log = findLog(medicineID: medicineID, scheduled: scheduled) {
            switch log.status {
            case "taken": return .taken
            case "skipped": return .skipped
            case "missed": return .missed
            default: break
            }
        }
        if scheduled > Date() { return .upcoming }
        return Date().timeIntervalSince(scheduled) > 7200 ? .missed : .upcoming
    }

    private func mark(occurrence: DoseOccurrence, as newStatus: DoseStatus) {
        guard let medicineID = occurrence.med?.medicine_ID else { return }
        let log = findLog(medicineID: medicineID, scheduled: occurrence.scheduled) ?? DoseLog(context: viewContext)
        if log.log_ID == nil { log.log_ID = UUID().uuidString }
        log.medicine_ID = medicineID
        log.medication_name = occurrence.medicationName   // persist name for future historical display
        log.scheduled_time = occurrence.scheduled
        log.actual_time = Date()
        log.status = newStatus.rawValue
        do {
            try viewContext.save()
            rebuildOccurrences()
        } catch {
            print("Failed to mark dose: \(error)")
        }
    }
}

#Preview {
    MedicationOverviewView()
}
