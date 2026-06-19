import SwiftUI
import CoreData

struct ContentView: View {
    @State private var currentView = "home"
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MyMedication.time_of_day, ascending: true)]
    ) var medications: FetchedResults<MyMedication>
    
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
                    
                    // Next Up card
                    if let med = medications.first {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: med.medication_icon ?? "pill.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.white)
                                        .frame(width: 55, height: 55)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color(.systemBlue))
                                        )
                                    VStack(alignment: .leading) {
                                        Text(med.medication_name ?? "Unknown")
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundStyle(.black)
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
                                        Text(med.time_of_day?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundStyle(.black)
                                    }
                                    Spacer()
                                    VStack{
                                        Spacer()
                                        Button(action: {
                                            print("Marked as taken")
                                        }) {
                                            Text("taken")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 120, height: 45)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                        .fill(Color(.blue))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                        .stroke(Color.blue.opacity(0.75), lineWidth: 2)
                                                )
                                        }
                                        
                                        Button(action: {
                                            print("Skip")
                                        }) {
                                            Text("Skip")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 120, height: 45)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                        .fill(Color(.orange))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                        .stroke(Color.orange.opacity(0.75), lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(.white))
                        )
                        .padding(.horizontal)
                    } else {
                        // Empty state
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No medications yet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.gray)
                                Text("Tap the pill icon below to add one")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(.white))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Schedule section
                    if !medications.isEmpty {
                        VStack {
                            HStack {
                                Text("Schedule")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.gray)
                                Spacer()
                            }
                            .padding(.top, 12)
                            .padding(.bottom, -4)
                            .padding(.horizontal)
                            
                            VStack {
                                ForEach(Array(medications.enumerated()), id: \.element.objectID) { index, med in
                                    if index > 0 {
                                        Divider()
                                            .padding(.vertical, 4)
                                    }
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.blue)
                                        VStack(alignment: .leading) {
                                            Text(med.medication_name ?? "Unknown")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(.black)
                                            Text(med.medication_type ?? "")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        Text(med.time_of_day?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color(.white))
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                
                // Nav buttons
                VStack {
                    HStack {
                        HStack {
                            NavigationLink(destination: MedicationOverviewView()) {
                                Circle()
                                    .fill(Color(.white).opacity(0.65))
                                    .frame(width: 45, height: 45)
                                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                    .overlay(Image(systemName: "chart.pie").foregroundStyle(.indigo))
                            }
                            
                            NavigationLink(destination: MedicineListView(currentView: $currentView)
                                .environment(\.managedObjectContext, viewContext)) {
                                    Circle()
                                        .fill(Color(.white).opacity(0.65))
                                        .frame(width: 45, height: 45)
                                        .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                        .overlay(Image(systemName: "pill").foregroundStyle(.pink))
                                }
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: Settings()) {
                            Circle()
                                .fill(Color(.white).opacity(0.65))
                                .frame(width: 45, height: 45)
                                .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                                .overlay(Image(systemName: "gear").foregroundStyle(.gray))
                        }
                    }
                    .padding(.horizontal, 30)
                }
            }
            .background(Color(.systemGray6))
        }
    }
}

#Preview {
    ContentView()
}
