import SwiftUI

@available(macOS 14.0, *)
struct SoundpackPickerStepView: View {
    @State private var audio = OnboardingAudio.shared
    @ObservedObject private var registry = OnboardingAudio.shared.registry
    @State private var installed: [Soundpack] = []
    @State private var highlighted: UUID?
    @FocusState private var focused: Bool

    private struct Item: Identifiable {
        let id: UUID
        let name: String
        let brand: String
        let pack: Soundpack?
        let entry: SoundpackRegistryEntry?
    }

    var body: some View {
        VStack(spacing: 24) {
            OnboardingTitleBlock(
                title: L10n.onboardingChooseSoundTitle,
                body: L10n.onboardingChooseSoundBody
            )

            Group {
                if items.isEmpty && audio.status != .ready {
                    OnboardingSoundState()
                } else {
                    list
                }
            }
                .mask(
                    VStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 28)
                    }
                )
                .frame(height: OnboardingMetrics.listInset + 5 * (OnboardingMetrics.rowHeight + OnboardingMetrics.rowSpacing) + 14)
                .onboardingPanel(cornerRadius: OnboardingMetrics.panelRadius)
        }
        .onAppear {
            OnboardingKeyMonitor.shared.acquire()
            refresh()
            audio.syncCurrentSoundpack()
            highlighted = audio.currentSoundpackId ?? items.first?.id
            focused = true
        }
        .onDisappear { OnboardingKeyMonitor.shared.release() }
        .onReceive(NotificationCenter.default.publisher(for: .soundpackLibraryDidChange)) { _ in refresh() }
    }

    private var items: [Item] {
        let installedIds = Set(installed.map(\.id))
        let local = installed.map { Item(id: $0.id, name: $0.name, brand: $0.brand, pack: $0, entry: nil) }
        let remote = registry.keyboardEntries
            .filter { !installedIds.contains($0.id) }
            .map { Item(id: $0.id, name: $0.metadata.name, brand: $0.metadata.brand, pack: nil, entry: $0) }
        return local + remote
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: OnboardingMetrics.rowSpacing) {
                    ForEach(items) { item in
                        row(item)
                            .id(item.id)
                            .onTapGesture { activate(item) }
                    }
                    if items.isEmpty {
                        HStack(spacing: 8) {
                            if registry.isLoading { ProgressView().controlSize(.small) }
                            Text(registry.isLoading ? L10n.onboardingLoadingSoundpacks : L10n.onboardingNoSoundpacks)
                                .font(OnboardingTheme.body)
                                .foregroundStyle(OnboardingTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding(OnboardingMetrics.listInset)
            }
            .scrollIndicators(.never)
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(.upArrow) { move(-1, proxy: proxy); return .handled }
            .onKeyPress(.downArrow) { move(1, proxy: proxy); return .handled }
        }
    }

    private func row(_ item: Item) -> some View {
        let isHighlighted = highlighted == item.id
        let isCurrent = audio.currentSoundpackId == item.id
        let isDownloading = registry.downloadingIds.contains(item.id)

        return HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(OnboardingTheme.chipFill))
            Text(item.name)
                .font(OnboardingTheme.rowTitle)
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text(item.brand)
                .font(OnboardingTheme.rowTitle)
                .foregroundStyle(OnboardingTheme.textTertiary)
            Spacer(minLength: 8)
            if isDownloading {
                ProgressView().controlSize(.small)
            } else if let entry = item.entry {
                Text(L10n.onboardingDownload + " · " + ByteCountFormatter.string(fromByteCount: Int64(entry.download.size), countStyle: .file))
                    .font(OnboardingTheme.caption)
                    .foregroundStyle(OnboardingTheme.textTertiary)
            } else if isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: OnboardingMetrics.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: OnboardingMetrics.panelRadius - OnboardingMetrics.listInset, style: .continuous)
                .fill(isHighlighted ? OnboardingTheme.selection : .clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.name), \(item.brand)"))
        .accessibilityValue(Text(isCurrent ? L10n.onboardingSelected : (item.pack == nil ? L10n.onboardingNotDownloaded : "")))
        .accessibilityAddTraits(.isButton)
    }

    private func move(_ delta: Int, proxy: ScrollViewProxy) {
        let list = items
        guard !list.isEmpty else { return }
        let index = list.firstIndex { $0.id == highlighted } ?? 0
        let next = list[min(max(index + delta, 0), list.count - 1)]
        highlighted = next.id
        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(next.id) }
        if let pack = next.pack { preview(pack) }
    }

    private func activate(_ item: Item) {
        highlighted = item.id
        if let pack = item.pack {
            preview(pack)
        } else if let entry = item.entry {
            Task {
                if let pack = await audio.install(entry) {
                    refresh()
                    if highlighted == item.id { preview(pack) }
                }
            }
        }
    }

    private func preview(_ pack: Soundpack) {
        audio.select(pack)
        OnboardingKeyboardModel.shared.demoPress()
    }

    private func refresh() {
        installed = audio.installedKeyboardSoundpacks()
    }
}
