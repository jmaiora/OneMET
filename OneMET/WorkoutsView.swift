import SwiftUI

// WorkoutsView.swift — OneMET Workouts tab (rings + history by week). v2.
// The whole tab is OneMET Pro: without a subscription it shows what's inside and the way
// to unlock it.

struct WorkoutsView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var subs: SubscriptionStore
    var accent: Color
    var lang: AppLanguage = .en
    var onOpenWorkout: (WorkoutSession) -> Void

    @State private var visibleWeeks = 2

    var body: some View {
        if subs.isPro { history } else { locked }
    }

    /// The tab's header, then a blurred sample session to show what the tab holds — sample
    /// data, never the person's own — and the button to the paywall.
    private var locked: some View {
        ScreenScaffold {
            AppHeader(title: lang.t("workouts.title"), date: lang.t("workouts.history"),
                      initials: profileStore.profile.initials, accent: accent)

            Card(pad: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    if let sample = SampleData.workoutHistory.first?.sessions.first {
                        WorkoutChart(session: sample, accent: accent, height: 150,
                                     unit: profileStore.profile.glucoseUnit, lang: lang)
                            .blur(radius: 4)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    Text(lang.t("pro.workoutsTitle"))
                        .font(.app(size: 20, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lang.t("pro.workoutsBody"))
                        .font(Theme.noteFont)
                        .lineSpacing(Theme.noteLineSpacing)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { subs.requirePro {} } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.app(size: 15, weight: .semibold))
                            Text(lang.t("pro.unlock"))
                                .font(.app(size: 17, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        let d = store.data
        let unit = profileStore.profile.glucoseUnit
        let r = d.rings
        let weeks = Array(d.workoutHistory.prefix(visibleWeeks))
        let total = d.workoutHistory.reduce(0) { $0 + $1.sessions.count }
        let shown = weeks.reduce(0) { $0 + $1.sessions.count }

        ScreenScaffold(onRefresh: { await store.refresh() }) {
            AppHeader(title: lang.t("workouts.title"), date: lang.t("workouts.history"),
                      initials: profileStore.profile.initials, accent: accent)

            // Rings hero
            Card(pad: 20) {
                HStack {
                    Spacer()
                    ActivityRings(size: 140, stroke: 14, fractions: [r.move.frac, r.exer.frac, r.met.frac])
                    Spacer()
                }
                .padding(.bottom, 16)
                VStack(alignment: .leading, spacing: 12) {
                    RingStat(color: Theme.ringMove, label: lang.t("summary.move"), value: r.move.value, goal: r.move.goal, unit: "kcal")
                    RingStat(color: Theme.ringExer, label: lang.t("summary.exercise"), value: r.exer.value, goal: r.exer.goal, unit: lang.t("workouts.min"))
                    RingStat(color: Theme.ringMet, label: lang.t("summary.met"), value: r.met.value, goal: r.met.goal, unit: "MET·min")
                }
            }

            if d.workoutHistory.isEmpty {
                Card(title: lang.t("workouts.noneShown"), icon: "run", iconColor: Theme.amber) {
                    Text(store.workoutDiagnostic ?? lang.t("workouts.noneYet"))
                        .font(Theme.noteFont)
                        .lineSpacing(Theme.noteLineSpacing)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ForEach(weeks) { wk in
                Card(title: wk.label, icon: "run", iconColor: accent,
                     right: lang.t(wk.sessions.count == 1 ? "workouts.one" : "workouts.many",
                                   String(wk.sessions.count))) {
                    VStack(spacing: 0) {
                        ForEach(Array(wk.sessions.enumerated()), id: \.element.id) { i, s in
                            HistoryRow(session: s, accent: accent, unit: unit, lang: lang,
                                       last: i == wk.sessions.count - 1,
                                       onDelete: { withAnimation(.easeInOut(duration: 0.25)) { store.deleteWorkout(s) } }) {
                                onOpenWorkout(s)
                            }
                        }
                    }
                }
            }

            if shown < total {
                Button { visibleWeeks += 2 } label: {
                    Text(lang.t("workouts.loadPast"))
                        .font(.app(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HistoryRow: View {
    var session: WorkoutSession
    var accent: Color
    var unit: GlucoseUnit = .mgdl
    var lang: AppLanguage = .en
    var last: Bool
    /// Swipe left to reveal Delete, which asks before removing the session from OneMET.
    /// Nil leaves the row without the swipe.
    var onDelete: (() -> Void)? = nil
    var onTap: () -> Void

    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0
    @State private var dragAxis: Axis? = nil
    @State private var confirmingDelete = false
    private let revealWidth: CGFloat = 88
    /// Dragging this far opens the confirmation straight away, like a full swipe in Mail.
    private let fullSwipe: CGFloat = 200

    var body: some View {
        ZStack(alignment: .trailing) {
            if onDelete != nil && offset < 0 {
                Button { confirmingDelete = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill").font(.app(size: 17, weight: .semibold))
                        Text(lang.t("workouts.delete"))
                            .font(.app(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(.white)
                    .frame(width: max(revealWidth, -offset))
                    .frame(maxHeight: .infinity)
                    .background(Theme.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
            row
                // Opaque, so the Delete button behind stays hidden until the row uncovers it.
                .background(Theme.card)
                .offset(x: offset)
        }
        .clipped()
        // Simultaneous, and only once the drag is clearly sideways, so vertical scrolling
        // through the list still works when it starts on a row.
        .simultaneousGesture(swipe, including: onDelete == nil ? .none : .all)
        .accessibilityAction(named: Text(lang.t("workouts.delete"))) {
            if onDelete != nil { confirmingDelete = true }
        }
        .confirmationDialog(lang.t("workouts.deleteTitle"), isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button(lang.t("workouts.delete"), role: .destructive) { onDelete?() }
            Button(lang.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(lang.t("workouts.deleteBody"))
        }
        .onChange(of: confirmingDelete) { open in
            if !open { close() }
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
        restingOffset = 0
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                if dragAxis == nil {
                    dragAxis = abs(v.translation.width) > abs(v.translation.height) ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }
                offset = min(0, restingOffset + v.translation.width)
            }
            .onEnded { v in
                defer { dragAxis = nil }
                guard dragAxis == .horizontal else { return }
                if restingOffset + v.translation.width < -fullSwipe {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = -revealWidth }
                    restingOffset = -revealWidth
                    confirmingDelete = true
                    return
                }
                let end = restingOffset + v.predictedEndTranslation.width
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    offset = end < -revealWidth / 2 ? -revealWidth : 0
                }
                restingOffset = offset
            }
    }

    private var row: some View {
        let dropColor = session.glucoseDelta < 0 ? Theme.green : Theme.amber
        // A tap on an open row closes it rather than opening the session.
        return Button(action: { if restingOffset != 0 { close() } else { onTap() } }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent.opacity(0.09))
                        AppIconView(name: session.icon, color: accent, size: 20)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("\(session.day) · \(session.time) · \(session.dur)")
                            .font(.app(size: 14))
                            .foregroundStyle(Theme.ink2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 3) {
                        Chip(unit.deltaAmount(Double(session.glucoseDelta)), color: dropColor)
                        Text(lang.t("workouts.metAvg", fmtNum(session.avgMet)))
                            .font(.app(size: 12.5))
                            .foregroundStyle(Theme.ink3)
                            .monospacedDigit()
                    }
                    AppIconView(name: "chevron", color: Theme.ink3, size: 14)
                }
                .padding(.vertical, 10)

                if !last { Rectangle().fill(Theme.sep).frame(height: 0.5) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.bg.ignoresSafeArea()
        WorkoutsView(accent: Theme.accent, onOpenWorkout: { _ in })
            .environmentObject(HealthDataStore())
            .environmentObject(ProfileStore())
            .environmentObject(SubscriptionStore())
    }
}
