//
//  MissionLibrary.swift
//  Offline_Mission_Control
//
//  Discovers + decodes bundled mission-log JSON files (Resources/Missions/*.json).
//

import Foundation

struct MissionSummary: Identifiable, Sendable, Hashable {
    var id: String { fileName }
    let fileName: String
    let url: URL
    let title: String
    let stepCount: Int
    let estTimeMin: Int?
}

enum MissionLibrary {
    /// All bundled mission JSON URLs. Tries the `Missions/` subdirectory first, then falls back
    /// to the bundle root (synchronized-group resource copies can be flattened).
    static func availableURLs() -> [URL] {
        let inSubdir = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Missions") ?? []
        if !inSubdir.isEmpty { return inSubdir }
        return Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
    }

    static func load(_ url: URL) throws -> Mission {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Mission.self, from: data)
    }

    /// Picker rows — only files that successfully decode as a Mission survive.
    static func summaries() -> [MissionSummary] {
        availableURLs()
            .compactMap { url -> MissionSummary? in
                guard let mission = try? load(url) else { return nil }
                return MissionSummary(
                    fileName: url.lastPathComponent,
                    url: url,
                    title: mission.procedure.title,
                    stepCount: mission.nominalStepCount,
                    estTimeMin: mission.procedure.estTotalTimeMin
                )
            }
            .sorted { $0.title < $1.title }
    }

    static func mission(fileName: String) -> Mission? {
        guard let url = availableURLs().first(where: { $0.lastPathComponent == fileName }) else { return nil }
        return try? load(url)
    }
}
