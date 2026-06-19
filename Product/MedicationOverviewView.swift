import SwiftUI
import CoreData

fileprivate enum DoseStatus: String {
    case taken
    case missed
    case upcoming
}

fileprivate struct DoseOccurrence: Identifiable {
    let id = UUID()
    let med: MyMedication
    let scheduled: Date
    var status: DoseStatus
}

struct MedicationOverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MyMedication.medication_name, ascending: true)]
    ) private var medications: FetchedResults<MyMedication>

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var occurrences: [DoseOccurrence] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                daySelector
                ringSummaryCard
                timelineCard
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(UIColor.systemGray6))
        .navigationTitle("Overview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { rebuildOccurrences() }
        .onChange(of: medications.count) { _, _ in rebuildOccurrences() }
        .onChange(of: selectedDate) { _, _ in rebuildOccurrences() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Medication")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
                Text("Today")
                    .font(.system(size: 36, weight: .bold))
            }
            Spacer()
        }
    }

    private var daySelector: some View {
        let cal = Calendar.current
        let days = (-3...3).compactMap { offset -> Date? in
            cal.date(byAdding: .day, value: offset, to: selectedDate)
        }
        return HStack(spacing: 10) {
            ForEach(days, id: \.self) { day in
                let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                VStack(spacing: 6) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(isSelected ? Color.blue : Color.clear)
                        )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDate = cal.startOfDay(for: day)
                }
            }
            Spacer()
        }
    }

    private var ringSummaryCard: some View {
        let takenCount = occurrences.filter { $0.status == .taken }.count
        let missedCount = occurrences.filter { $0.status == .missed }.count
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
                        Label("\(takenCount) taken", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("\(missedCount) missed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Label("\(occurrences.count - takenCount - missedCount) upcoming", systemImage: "clock.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.gray)

            VStack(spacing: 0) {
                ForEach(occurrences) { occ in
                    timelineRow(for: occ)
                    if occ.id != occurrences.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
    }

    private func timelineRow(for occ: DoseOccurrence) -> some View {
        HStack(alignment: .center, spacing: 12) {
            let color: Color = {
                switch occ.status {
                case .taken: return .green
                case .missed: return .red
                case .upcoming: return .orange
                }
            }()
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: iconName(for: occ.status))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(occ.med.medication_name ?? "Unknown")
                    .font(.system(size: 18, weight: .semibold))
                HStack(spacing: 8) {
                    Text(occ.scheduled.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.gray)
                        .font(.system(size: 14, weight: .medium))
                    Text(occ.med.medication_type ?? "")
                        .foregroundStyle(.gray)
                        .font(.system(size: 12))
                }
            }
            Spacer()
            if occ.status != .taken {
                Button {
                    mark(occurrence: occ, as: .taken)
                } label: {
                    Text("Taken")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue))
                }
            }
            if occ.status != .missed {
                Button {
                    mark(occurrence: occ, as: .missed)
                } label: {
                    Text("Missed")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange))
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func iconName(for status: DoseStatus) -> String {
        switch status {
        case .taken: return "checkmark"
        case .missed: return "xmark"
        case .upcoming: return "clock"
        }
    }

    private func rebuildOccurrences() {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return }
        var items: [DoseOccurrence] = []

        for med in medications {
            let start = med.start_date ?? dayStart
            let hasEnd = med.has_end_date
            let end = med.end_date ?? dayEnd
            guard dayStart >= cal.startOfDay(for: start) else { continue }
            if hasEnd, dayStart > cal.startOfDay(for: end) { continue }

            switch med.frequency {
            case 0:
                if let t = med.time_of_day, cal.isDate(t, inSameDayAs: dayStart) {
                    items.append(DoseOccurrence(med: med, scheduled: t, status: statusFor(med: med, scheduled: t)))
                }
            case 1:
                if let t = med.time_of_day, let scheduled = combineDate(dayStart, time: t) {
                    items.append(DoseOccurrence(med: med, scheduled: scheduled, status: statusFor(med: med, scheduled: scheduled)))
                }
            case 2:
                if let t = med.time_of_day, let scheduled = combineDate(dayStart, time: t) {
                    items.append(DoseOccurrence(med: med, scheduled: scheduled, status: statusFor(med: med, scheduled: scheduled)))
                }
            case 3:
                let weekday = Int(med.selected_days)
                if let t = med.time_of_day,
                   cal.component(.weekday, from: dayStart) == weekday,
                   let scheduled = combineDate(dayStart, time: t) {
                    items.append(DoseOccurrence(med: med, scheduled: scheduled, status: statusFor(med: med, scheduled: scheduled)))
                }
            case 4:
                if let base = med.start_date, let t = med.time_of_day {
                    let n = max(Int(med.interval_days), 1)
                    let distance = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: dayStart).day ?? 0
                    if distance % n == 0, let scheduled = combineDate(dayStart, time: t) {
                        items.append(DoseOccurrence(med: med, scheduled: scheduled, status: statusFor(med: med, scheduled: scheduled)))
                    }
                }
            default:
                break
            }
        }

        items.sort { $0.scheduled < $1.scheduled }
        occurrences = items
    }

    private func combineDate(_ date: Date, time: Date) -> Date? {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        comps.hour = t.hour
        comps.minute = t.minute
        return cal.date(from: comps)
    }

    private func statusFor(med: MyMedication, scheduled: Date) -> DoseStatus {
        if let status = fetchEventStatusIfAvailable(med: med, scheduled: scheduled) {
            return status
        }
        if scheduled > Date() { return .upcoming }
        return Date().timeIntervalSince(scheduled) > 7200 ? .missed : .upcoming
    }

    private func fetchEventStatusIfAvailable(med: MyMedication, scheduled: Date) -> DoseStatus? {
        let model = viewContext.persistentStoreCoordinator?.managedObjectModel
        guard let eventEntity = model?.entitiesByName["MedicationEvent"] else { return nil }
        let request = NSFetchRequest<NSManagedObject>(entityName: eventEntity.name!)
        let cal = Calendar.current
        let start = cal.date(byAdding: .minute, value: -1, to: scheduled) ?? scheduled
        let end = cal.date(byAdding: .minute, value: 1, to: scheduled) ?? scheduled
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "medication == %@", med),
            NSPredicate(format: "scheduled >= %@ AND scheduled <= %@", start as NSDate, end as NSDate)
        ])
        request.fetchLimit = 1
        do {
            if let obj = try viewContext.fetch(request).first {
                let status = obj.value(forKey: "status") as? String ?? ""
                if status == "taken" { return .taken }
                if status == "missed" { return .missed }
            }
        } catch {}
        return nil
    }

    private func mark(occurrence: DoseOccurrence, as newStatus: DoseStatus) {
        if upsertEventIfPossible(for: occurrence, status: newStatus) {
            rebuildOccurrences()
            return
        }
        if let idx = occurrences.firstIndex(where: { $0.id == occurrence.id }) {
            occurrences[idx].status = newStatus
        }
    }

    private func upsertEventIfPossible(for occurrence: DoseOccurrence, status: DoseStatus) -> Bool {
        guard let model = viewContext.persistentStoreCoordinator?.managedObjectModel,
              let eventEntity = model.entitiesByName["MedicationEvent"] else { return false }

        let request = NSFetchRequest<NSManagedObject>(entityName: eventEntity.name!)
        let scheduled = occurrence.scheduled
        let cal = Calendar.current
        let start = cal.date(byAdding: .minute, value: -1, to: scheduled) ?? scheduled
        let end = cal.date(byAdding: .minute, value: 1, to: scheduled) ?? scheduled
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "medication == %@", occurrence.med),
            NSPredicate(format: "scheduled >= %@ AND scheduled <= %@", start as NSDate, end as NSDate)
        ])
        request.fetchLimit = 1

        do {
            let found = try viewContext.fetch(request).first
            let obj: NSManagedObject
            if let f = found { obj = f } else {
                obj = NSManagedObject(entity: eventEntity, insertInto: viewContext)
                obj.setValue(occurrence.med, forKey: "medication")
                obj.setValue(occurrence.scheduled, forKey: "scheduled")
            }
            obj.setValue(status.rawValue, forKey: "status")
            try viewContext.save()
            return true
        } catch {
            return false
        }
    }
}

#Preview {

        MedicationOverviewView()
}
