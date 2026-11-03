import SwiftUI

@available(macOS 14.0, *)
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case sound
    case permission
    case done
}

@available(macOS 14.0, *)
enum OnboardingMetrics {
    static let windowSize = CGSize(width: 720, height: 520)
    static let columnWidth: CGFloat = 440
    static let panelRadius: CGFloat = 16
    static let listInset: CGFloat = 8
    static let rowHeight: CGFloat = 36
    static let rowSpacing: CGFloat = 2
}

@available(macOS 14.0, *)
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var step: OnboardingStep = OnboardingStep(rawValue: UserDefaults.standard.integer(forKey: "onboardingStartStep")) ?? .welcome
    @State private var forward = true
    @State private var permission = AccessibilityPermissionWatcher()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: OnboardingMetrics.windowSize.width, height: OnboardingMetrics.windowSize.height)
        .onAppear(perform: scheduleDebugAutoAdvance)
        .onChange(of: permission.isGranted) { _, granted in
            guard granted, step == .permission else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if step == .permission { go(to: .done) }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            OnboardingStepIndicator(count: OnboardingStep.allCases.count, current: step.rawValue)
                .padding(.top, 52)

            ZStack {
                stepContent
                    .id(step)
                    .transition(stepTransition)
            }
            .frame(width: OnboardingMetrics.columnWidth)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 20)

            footer
                .frame(width: OnboardingMetrics.columnWidth)
                .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .sound:
            SoundpackPickerStepView()
        case .permission:
            PermissionStepView(watcher: permission)
        case .done:
            DoneStepView()
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step != .welcome && step != .done {
                OnboardingButton(L10n.onboardingBack, kind: .secondary, action: back)
                    .keyboardShortcut("[", modifiers: .command)
            }

            Spacer()

            if step == .permission && !permission.isGranted {
                OnboardingButton(L10n.onboardingSkipForNow, kind: .secondary, action: next)
                    .keyboardShortcut(.cancelAction)
                OnboardingButton(L10n.onboardingOpenSettings, kind: .primary) { permission.requestAccess() }
                    .keyboardShortcut(.defaultAction)
            } else {
                OnboardingButton(step == .done ? L10n.onboardingDone : L10n.onboardingContinue, kind: .primary, action: primaryAction)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func scheduleDebugAutoAdvance() {
        #if DEBUG
        let delay = UserDefaults.standard.double(forKey: "onboardingAutoAdvanceAfter")
        guard delay > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { next() }
        #endif
    }

    private func primaryAction() {
        if step == .done { onFinish() } else { next() }
    }

    private func next() {
        guard let target = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        go(to: target)
    }

    private func back() {
        guard step != .done, let target = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        go(to: target)
    }

    private func go(to target: OnboardingStep) {
        forward = target.rawValue > step.rawValue
        withAnimation(reduceMotion ? .linear(duration: 0.12) : .smooth(duration: 0.28)) {
            step = target
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)).animation(.easeOut(duration: 0.22).delay(0.12)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }
}
