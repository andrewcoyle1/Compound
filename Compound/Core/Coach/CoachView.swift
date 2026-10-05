//
//  CoachView.swift
//  Compound
//
//  The AI coach. Every "Ask Coach" button in the app opens this with the context it was asked
//  from; it checks premium and consent itself, so every way in behaves the same.
//

import SwiftUI

struct CoachDelegate {
    var context: CoachContext = .today
    /// A stored chat to continue; `nil` starts a new one.
    var chatId: String?
    /// The coach opened as a sheet closes; one pushed from the chat list goes Back instead.
    var showsCloseButton = true
}

struct CoachView: View {

    @State var presenter: CoachPresenter
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            switch presenter.gate {
            case .premium: premiumGate
            case .consent: consentGate
            case .chat: chat
            }
        }
        .navigationTitle(presenter.gate == .chat ? presenter.title : String(localized: "Coach"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

    // MARK: - Premium

    private var premiumGate: some View {
        ContentUnavailableView {
            Label("Coach Is Part of Premium", systemImage: Symbol.coach)
        } description: {
            Text("Ask about your training, nutrition and progress, answered from your own logs.")
        } actions: {
            Button {
                presenter.onSeePlansPressed()
            } label: {
                Text("See Plans")
                    .foregroundStyle(.onAccent)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Consent

    /// Apple's guideline 5.1.2(i): say what is shared and with whom, and ask, before any of it is.
    private var consentGate: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Image(systemName: Symbol.coach)
                        .iconSize(.large)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Before You Ask")
                        .font(.display)
                    Text("To answer, the coach reads your data in Compound and sends what each question needs to Google's Gemini model, running in the EU through Google Cloud.")
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            Section("What It Reads") {
                Label("Workouts, plans and notes", systemImage: Symbol.workout)
                Label("Meals, foods and nutrition targets", systemImage: Symbol.meal)
                Label("Weight, measurements and goals", systemImage: Symbol.scaleWeight)
                Label("Steps from Apple Health", systemImage: Symbol.steps)
            }
            Section {
                Label("Progress photos", systemImage: Symbol.camera)
                Label("Anything about the people you follow", systemImage: Symbol.friends)
                Label("Activities imported from Strava", systemImage: Symbol.cardio)
            } header: {
                Text("What It Never Reads")
            } footer: {
                Text("Google doesn't use your data to train its models. Your chats are saved so you can come back to them, and you can delete them, or withdraw this permission, from Settings at any time. The coach can make mistakes and isn't medical advice.")
            }
        }
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isGivingConsent) {
                presenter.onConsentAccepted()
            } label: {
                Text("Allow and Continue")
            }
            Button("Not Now") { presenter.onConsentDeclined() }
        }
    }

    // MARK: - Chat

    private var chat: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.m) {
                    if presenter.messages.isEmpty && presenter.streamingText == nil {
                        emptyState
                    }
                    ForEach(presenter.messages) { message in
                        bubble(message.text, role: message.role)
                            .id(message.id)
                    }
                    if let streaming = presenter.streamingText {
                        Group {
                            if streaming.isEmpty {
                                ProgressView()
                                    .padding(Spacing.m)
                            } else {
                                bubble(streaming, role: .assistant)
                            }
                        }
                        .id("streaming")
                    }
                    if let error = presenter.errorMessage {
                        InlineMessage(.warning, error)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: presenter.messages.count) { _, _ in
                withReducedMotionAnimation(.quick) { proxy.scrollTo(presenter.messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: presenter.streamingText) { _, _ in
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
        .background(.canvas)
        .safeAreaBar(edge: .bottom) { inputBar }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Ask about your training, food and progress. Answers come from what you've logged.")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
            ForEach(presenter.suggestedQuestions, id: \.self) { question in
                Button {
                    presenter.onSuggestedQuestionPressed(question)
                } label: {
                    Label(question, systemImage: Symbol.coach)
                        .font(.rowTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.m)
                        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func bubble(_ text: String, role: CoachMessage.Role) -> some View {
        let isUser = role == .user
        return HStack {
            if isUser { Spacer(minLength: Spacing.xxl) }
            Text(Self.markdown(text))
                .font(.rowTitle)
                .textSelection(.enabled)
                .padding(Spacing.m)
                .background(
                    isUser ? AnyShapeStyle(Color.tintedSurface(.accentColor)) : AnyShapeStyle(.surface),
                    in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                )
            if !isUser { Spacer(minLength: Spacing.xxl) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? Text("You: \(text)") : Text("Coach: \(text)"))
    }

    /// The model answers in light markdown: bold, italics, lists. Anything that does not parse
    /// shows as it came.
    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    private var inputBar: some View {
        VStack(spacing: Spacing.xs) {
            if let remaining = presenter.remainingText {
                Text(remaining)
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: Spacing.s) {
                TextField("Ask your coach", text: $presenter.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit { presenter.onSendPressed() }
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                Button {
                    presenter.onSendPressed()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .iconSize(.large)
                }
                .disabled(!presenter.canSend)
                .accessibilityLabel("Send")
            }
            Text("Answers come from your logs and can be wrong. Not medical advice.")
                .font(.label)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.s)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if presenter.delegate.showsCloseButton {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onClosePressed()
                }
            }
        }
        if presenter.gate == .chat {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New Chat", systemImage: Symbol.add) { presenter.onNewChatPressed() }
                    Button("Chats", systemImage: Symbol.history) { presenter.onChatsPressed() }
                } label: {
                    Image(systemName: Symbol.more)
                }
                .accessibilityLabel("More")
            }
        }
    }
}

extension CoreBuilder {
    func coachView(router: AnyRouter, delegate: CoachDelegate) -> some View {
        CoachView(presenter: CoachPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self),
            delegate: delegate
        ))
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.coachView(router: router, delegate: CoachDelegate(context: .today))
    }
}
