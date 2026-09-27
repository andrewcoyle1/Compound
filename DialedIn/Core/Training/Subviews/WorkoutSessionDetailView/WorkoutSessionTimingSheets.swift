//
//  WorkoutSessionTimingSheets.swift
//  DialedIn
//
//  The two pickers behind a finished session's Start Time and Duration rows. They hold no state of
//  their own: the session detail presenter owns the values and the save, and hands them over as
//  bindings, the way `showRestModal` does for the rest picker.
//

import SwiftUI

/// Changes save as the picker moves, so Done only closes.
struct WorkoutSessionStartTimeSheet: View {
    @Binding var date: Date
    let onDone: () -> Void

    var body: some View {
        Form {
            DatePicker("Started at", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
            Text("The workout keeps its duration; only when it started changes.")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Start Time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: onDone)
            }
        }
    }
}

struct WorkoutSessionDurationSheet: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    let onClose: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: $hours) {
                ForEach(0..<13, id: \.self) { hour in
                    Text("\(hour) hr").tag(hour)
                }
            }
            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60, id: \.self) { minute in
                    Text("\(minute) min").tag(minute)
                }
            }
        }
        .pickerStyle(.wheel)
        .padding(.horizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("Duration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: onClose)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: onSave)
            }
        }
    }
}

extension CoreRouter {
    func showSessionStartTimeView(date: Binding<Date>) {
        router.showScreen(.sheetConfig(config: .full)) { router in
            WorkoutSessionStartTimeSheet(date: date, onDone: { router.dismissScreen() })
        }
    }

    func showSessionDurationView(hours: Binding<Int>, minutes: Binding<Int>, onSave: @escaping () -> Void) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            WorkoutSessionDurationSheet(
                hours: hours,
                minutes: minutes,
                onClose: { router.dismissScreen() },
                onSave: {
                    onSave()
                    router.dismissScreen()
                }
            )
        }
    }
}

#Preview("Start time") {
    @Previewable @State var date = Date()
    NavigationStack {
        WorkoutSessionStartTimeSheet(date: $date, onDone: { })
    }
}

#Preview("Duration") {
    @Previewable @State var hours = 1
    @Previewable @State var minutes = 15
    NavigationStack {
        WorkoutSessionDurationSheet(hours: $hours, minutes: $minutes, onClose: { }, onSave: { })
    }
}
