//
//  DevSettingsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/22/24.
//

#if DEV || MOCK
import SwiftUI

struct DevSettingsView: View {
    
    @State var presenter: DevSettingsPresenter

    var body: some View {
        List {
#if DEV || MOCK
            premiumSection
#endif
            abTestSection
            debugActionsSection
            authSection
            userSection
            deviceSection
            activeWorkoutSessionSection
            localStorageDebugSection
            firebaseTestSection
            exerciseModelSection
            workoutTemplateSection
            seedingSection
            shareCardSection
        }
        .navigationTitle("Developer Settings")
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                backButtonView
            }
        }
        .onFirstAppear {
            presenter.loadABTests()
#if DEV || MOCK
            presenter.loadPremiumOverride()
#endif
        }
    }
        
    private var backButtonView: some View {
        Image(systemName: "xmark")
            .anyButton {
                presenter.onDismissPressed()
            }
        .accessibilityLabel("Close")
    }

    private var authSection: some View {
        Section {
            let array = presenter.authParams()
            ForEach(array, id: \.key) { item in
                itemRow(item: item)
            }
        } header: {
            Text("Auth Info")
        }
    }
    
    private var userSection: some View {
        Section {
            let array = presenter.userParams()
            ForEach(array, id: \.key) { item in
                itemRow(item: item)
            }
        } header: {
            Text("User Info")
        }
    }
    
#if DEV || MOCK
    private var premiumSection: some View {
        Section {
            Toggle("Simulate Premium", isOn: $presenter.simulatePremium)
                .onChange(of: presenter.simulatePremium, presenter.handleSimulatePremiumChange)
                .font(.caption)
        } header: {
            Text("Subscription")
        } footer: {
            Text("Treats this device as a subscriber without a purchase. Debug and Mock builds only — it does not exist in a release build.")
                .font(.caption2)
        }
    }
#endif

    private var abTestSection: some View {
        Section {
            Group {
                Toggle("Notifications Test", isOn: $presenter.isInNotificationsABTest)
                    .onChange(of: presenter.isInNotificationsABTest, presenter.handleNotificationTestChange)
                
                Picker("Paywall Test", selection: $presenter.paywallTest) {
                    ForEach(PaywallTestOption.allCases, id: \.self) { option in
                        Text(option.rawValue)
                            .id(option)
                    }
                }
                .onChange(of: presenter.paywallTest, presenter.handlePaywallOptionChange)
            }
            .font(.caption)
        } header: {
            Text("AB Tests")
        }
    }
    
    private var deviceSection: some View {
        Section {
            let array = presenter.deviceParams()
            ForEach(array, id: \.key) { item in
                itemRow(item: item)
            }
        } header: {
            Text("Device Info")
        }
    }
    
    private var exerciseModelSection: some View {
        Group {
            Section {
                ForEach(presenter.allExercises, id: \.id) { item in
                    CustomListCellView(imageName: item.imageURL, title: item.name, subtitle: item.description)
                        .removeListRowFormatting()
                }
            } header: {
                HStack {
                    Text("Exercises")
                    Spacer()
                    Text("\(presenter.allExercises.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var workoutTemplateSection: some View {
        Group {
            Section {
                ForEach(presenter.allWorkoutTemplates, id: \.workoutId) { workout in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(workout.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        if let description = workout.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.caption2)
                            Text("\(workout.exercises.count) exercises")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Workout Templates")
                    Spacer()
                    Text("\(presenter.allWorkoutTemplates.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var activeWorkoutSessionSection: some View {
        Section {
            if let session = presenter.activeSession {
                VStack(alignment: .leading, spacing: 8) {
                    debugRow(label: "Session ID", value: session.id)
                    debugRow(label: "Name", value: session.name)
                    debugRow(label: "Template ID", value: session.workoutTemplateId ?? "nil")
                    debugRow(label: "Plan ID", value: session.trainingProgramId ?? "nil")
                    debugRow(label: "Created", value: session.dateCreated.formatted(date: .numeric, time: .shortened))
                    if let endedAt = session.endedAt {
                        debugRow(label: "Ended", value: endedAt.formatted(date: .numeric, time: .shortened))
                    } else {
                        debugRow(label: "Ended", value: "nil (in progress)")
                    }
                    debugRow(label: "Exercises", value: "\(session.exercises.count)")
                    
                    let completedSets = session.exercises.flatMap { $0.sets }.filter { $0.completedAt != nil }.count
                    let totalSets = session.exercises.flatMap { $0.sets }.count
                    debugRow(label: "Sets", value: "\(completedSets)/\(totalSets)")
                }
                .padding(.vertical, 4)
            } else {
                Text("No active workout session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Active Workout Session")
        } footer: {
            Text("Shows the currently active workout session if one is in progress.")
        }
    }
    
    private var localStorageDebugSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // Active session from local storage
                if let activeSession = presenter.activeSession {
                    Text("Active Session (Local)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        debugRow(label: "  Session ID", value: activeSession.id)
                        debugRow(label: "  Template ID", value: activeSession.workoutTemplateId ?? "nil")
                        debugRow(label: "  Plan ID", value: activeSession.trainingProgramId ?? "nil")
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                } else {
                    Text("No active session in local storage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Recent sessions
                let recentSessions = presenter.workoutSessions
                let last3 = Array(recentSessions.sorted(by: { $0.dateCreated > $1.dateCreated }).prefix(3))
                
                Text("Recent Sessions (Last 3)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                if last3.isEmpty {
                    Text("No recent sessions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(last3, id: \.id) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            debugRow(label: "  Session ID", value: String(session.id.prefix(8)) + "...")
                            debugRow(label: "  Template ID", value: session.workoutTemplateId ?? "nil")
                            debugRow(label: "  Plan ID", value: session.trainingProgramId ?? "nil")
                            debugRow(label: "  Created", value: session.dateCreated.formatted(date: .numeric, time: .shortened))
                            if let ended = session.endedAt {
                                debugRow(label: "  Ended", value: ended.formatted(date: .numeric, time: .shortened))
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
            .padding(.vertical, 4)
            
        } header: {
            Text("Local Storage Debug")
        }
    }
    
    private var firebaseTestSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fetch Session from Firebase")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                TextField("Session ID", text: $presenter.testSessionId)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                
                Button {
                    Task {
                        await presenter.fetchSessionFromFirebase()
                    }
                } label: {
                    if presenter.isFetchingSession {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Fetch Session", systemImage: "arrow.down.circle")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(presenter.testSessionId.isEmpty || presenter.isFetchingSession)
                
                if let error = presenter.fetchError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
                
                if let session = presenter.fetchedSession {
                    Divider()
                    
                    Text("Fetched Session")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        debugRow(label: "  Session ID", value: String(session.id.prefix(8)) + "...")
                        debugRow(label: "  Name", value: session.name)
                        debugRow(label: "  Template ID", value: session.workoutTemplateId ?? "nil")
                        debugRow(label: "  Plan ID", value: session.trainingProgramId ?? "nil")
                        debugRow(label: "  Created", value: session.dateCreated.formatted(date: .numeric, time: .shortened))
                        if let ended = session.endedAt {
                            debugRow(label: "  Ended", value: ended.formatted(date: .numeric, time: .shortened))
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Firebase Test")
        }
    }
    
    private var seedingSection: some View {
        Section {
            Button {
                Task {
                    await presenter.resetExerciseSeeding()
                }
            } label: {
                Label("Reset Exercise Seeding", systemImage: "arrow.clockwise")
            }
            .disabled(presenter.isReseeding)
            
            Button {
                Task {
                    await presenter.resetWorkoutSeeding()
                }
            } label: {
                Label("Reset Workout Seeding", systemImage: "arrow.clockwise")
            }
            .disabled(presenter.isReseeding)

            Button {
                Task {
                    await presenter.resetProgramSeeding()
                }
            } label: {
                Label("Reset Program Seeding", systemImage: "arrow.clockwise")
            }
            .disabled(presenter.isReseeding)
            
            Button {
                Task {
                    await presenter.resetAllSeeding()
                }
            } label: {
                Label("Reset All Seeding", systemImage: "arrow.clockwise.circle.fill")
            }
            .disabled(presenter.isReseeding)
            
            if presenter.isReseeding {
                HStack {
                    ProgressView()
                    Text(presenter.reseedingMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Data Seeding")
        } footer: {
            Text("Use these options to reset and re-seed system exercises, workouts and programs. Useful for testing or if seeding failed.")
        }
    }
    
    private var shareCardSection: some View {
        Section {
            Button("Save Share Cards to Photos") {
                presenter.onSaveShareCardsPressed()
            }
        } header: {
            Text("Share Card")
        } footer: {
            Text("Renders the Story and Square cards for the first mock session and saves both to the photo library.")
        }
    }

    @ViewBuilder
    private var debugActionsSection: some View {
        Section {
            Button(role: .destructive) {
                presenter.onForceFreshAnonUser()
            } label: {
                Text("Clear local data & sign out")
            }
            .tint(.red)
            .font(.caption)

        } header: {
            Text("Debug Actions")
        } footer: {
            Text("Clears all local data and signs out. Your Firebase account remains intact.")
        }
    }
    
    private func itemRow(item: (key: String, value: Any)) -> some View {
        HStack {
            Text(item.key)
            Spacer(minLength: 4)
            
            if let value = String.convertToString(item.value) {
                Text(value)
            } else {
                Text("Unknown")
            }
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.3)
    }
    
    private func debugRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

extension CoreBuilder {
    func devSettingsView(router: AnyRouter) -> AnyView {
        DevSettingsView(
            presenter: DevSettingsPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
        .any()
    }
}

extension CoreRouter {
    func showDevSettingsView() {
        router.showScreen(.fullScreenCover) { router in
            builder.devSettingsView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.devSettingsView(router: router)
    }
    
}
#endif
