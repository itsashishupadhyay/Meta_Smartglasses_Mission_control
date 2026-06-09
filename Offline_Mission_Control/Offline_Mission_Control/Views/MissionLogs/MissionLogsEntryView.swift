//
//  MissionLogsEntryView.swift
//  Offline_Mission_Control
//
//  "Start Mission Logs" setup: choose a bundled mission JSON, choose the detection model, review
//  the COCO-proxy legend, opt into voice confirmation, then launch the guided procedure.
//

import SwiftUI

struct MissionLogsEntryView: View {
    var vm: MissionControlViewModel
    var onCancel: () -> Void

    @State private var summaries: [MissionSummary] = []
    @State private var selectedFile = ""
    @State private var selectedMission: Mission?
    @State private var speechEnabled = true
    @State private var starting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    intro
                    if summaries.isEmpty {
                        empty
                    } else {
                        missionSection
                        modelSection
                        targetSection
                        if let mission = selectedMission, !mission.legend.isEmpty { legendSection(mission) }
                        speechSection
                        if speechEnabled { strictnessSection }
                        startButton
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .missionBackground()
            .navigationTitle("Mission Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear(perform: loadLibrary)
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.clipboard.fill")
                .font(.system(size: 40)).foregroundStyle(Theme.accent)
            Text("Guided Mission Logs")
                .font(.title3.bold()).foregroundStyle(Theme.textPrimary)
            Text("Run a procedure hands-free: show the object for each step to hear the cue and start its timer, then say the call-out to advance.")
                .font(.callout).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var empty: some View {
        Text("No mission JSON files found in the app bundle (Resources/Missions).")
            .font(.callout).foregroundStyle(Theme.textTertiary)
            .multilineTextAlignment(.center)
            .glassCard()
    }

    private var missionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Mission")
            Menu {
                ForEach(summaries) { summary in
                    Button { select(summary.fileName) } label: {
                        Label(summary.title, systemImage: selectedFile == summary.fileName ? "checkmark" : "doc.text")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedMission?.procedure.title ?? "Select a mission")
                            .font(.body.weight(.medium)).foregroundStyle(Theme.textPrimary).lineLimit(2)
                        if let s = summaries.first(where: { $0.fileName == selectedFile }) {
                            Text("\(s.stepCount) steps · ~\(s.estTimeMin ?? 0) min")
                                .font(.telemetry(11)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            }
        }
        .glassCard()
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Detection Model")
            Menu {
                ForEach(DetectionModelOption.all) { model in
                    Button {
                        if model.isAvailable { vm.settings.modelID = model.id }
                    } label: {
                        Label(model.displayName + (model.isAvailable ? "" : " — not added"),
                              systemImage: vm.settings.modelID == model.id ? "checkmark" : model.systemImage)
                    }
                    .disabled(!model.isAvailable)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: vm.settings.selectedModel.systemImage).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.settings.selectedModel.displayName)
                            .font(.body.weight(.medium)).foregroundStyle(Theme.textPrimary)
                        Text("\(vm.settings.selectedModel.dataset) · \(vm.settings.selectedModel.classCount) classes")
                            .font(.telemetry(11)).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            }
            Text("This mission's object triggers are everyday COCO classes — the COCO model is recommended.")
                .font(.caption).foregroundStyle(Theme.textTertiary)
        }
        .glassCard()
    }

    private func legendSection(_ mission: Mission) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(mission.legend) { entry in
                    HStack(spacing: 8) {
                        Circle().fill(DetectionPalette.color(for: entry.cocoClass)).frame(width: 9, height: 9)
                        Text(entry.cocoClass).font(.telemetry(12, weight: .medium)).foregroundStyle(Theme.textPrimary)
                        Text("= \(entry.represents)").font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text("PROXY LEGEND").font(.caption.weight(.semibold)).tracking(1.6).foregroundStyle(Theme.textTertiary)
        }
        .tint(Theme.accent)
        .glassCard()
    }

    private var speechSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $speechEnabled) {
                Label("Voice confirmation", systemImage: "mic.fill")
                    .foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.accent)
            Text("Listens on-device for your spoken call-out to advance steps automatically. You can always swipe or tap Confirm instead.")
                .font(.caption).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard()
    }

    private var targetSection: some View {
        VStack(spacing: 16) {
            SliderCard(
                title: "Target Confidence",
                blurb: "Minimum confidence for a step's target object. 0 uses each object's value from the mission file.",
                valueText: vm.settings.missionConfidence > 0 ? "\(Int(vm.settings.missionConfidence * 100))%" : "JSON",
                value: Binding(get: { vm.settings.missionConfidence }, set: { vm.settings.missionConfidence = $0 }),
                range: 0...0.9,
                step: 0.05,
                minLabel: "JSON",
                maxLabel: "90%"
            )
            SliderCard(
                title: "Target Appear For",
                blurb: "How long a target must stay in view before its step activates. 0 uses your Detection-settings dwell.",
                valueText: dwellLabel(vm.settings.missionDwellSeconds),
                value: Binding(get: { vm.settings.missionDwellSeconds }, set: { vm.settings.missionDwellSeconds = $0 }),
                range: 0...5,
                step: 0.5,
                minLabel: "Default",
                maxLabel: "5s"
            )
        }
    }

    private func dwellLabel(_ value: Double) -> String {
        if value <= 0 { return "Default" }
        return value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))s" : String(format: "%.1fs", value)
    }

    private var strictnessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Voice Match")
            ForEach(MissionMatchStrictness.allCases) { level in
                OptionRow(
                    title: level.title,
                    subtitle: level.subtitle,
                    systemImage: icon(for: level),
                    isSelected: vm.settings.missionStrictness == level
                ) {
                    vm.settings.missionMatchStrictness = level.rawValue
                }
            }
            Text("How closely your spoken call-out must match the step's confirmation phrase to auto-advance.")
                .font(.caption).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard()
    }

    private func icon(for level: MissionMatchStrictness) -> String {
        switch level {
        case .strict: "minus.circle.fill"
        case .balanced: "equal.circle.fill"
        case .lenient: "plus.circle.fill"
        }
    }

    private var startButton: some View {
        Button {
            start()
        } label: {
            Label(starting ? "Starting…" : "Start Mission", systemImage: "play.fill")
        }
        .buttonStyle(.missionProminent)
        .disabled(selectedMission == nil || starting)
    }

    // MARK: - Actions

    private func loadLibrary() {
        summaries = MissionLibrary.summaries()
        let preferred = vm.settings.selectedMissionFileName
        if let match = summaries.first(where: { $0.fileName == preferred }) {
            select(match.fileName)
        } else if let first = summaries.first {
            select(first.fileName)
        }
    }

    private func select(_ fileName: String) {
        selectedFile = fileName
        selectedMission = MissionLibrary.mission(fileName: fileName)
        vm.settings.selectedMissionFileName = fileName
    }

    private func start() {
        guard let mission = selectedMission else { return }
        starting = true
        Task {
            var speech = speechEnabled
            if speechEnabled {
                speech = await SpeechListener.requestAuthorization()
            }
            await vm.startMissionLogs(mission, speechEnabled: speech)
            starting = false
        }
    }
}
