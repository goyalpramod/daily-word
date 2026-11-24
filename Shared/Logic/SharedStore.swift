import Foundation
import SwiftData
import os

/// Configuration shared by the app and the widget extension.
enum SharedConfig {
    static let logger = Logger(subsystem: "DailyWord", category: "store")

    /// Injected into Info.plist from DW_BUNDLE_PREFIX (see project.yml).
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "DWAppGroup") as? String ?? ""
    }

    static var cloudContainerID: String {
        Bundle.main.object(forInfoDictionaryKey: "DWCloudContainer") as? String ?? ""
    }

    /// Small, device-local UI state (e.g. "is the widget card flipped").
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

enum DataStore {
    /// One container per process, pointing at the same store file inside the
    /// App Group, so the app and the widget read and write the same progress.
    static let container: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([ReviewState.self, CustomEntry.self])
        let group: ModelConfiguration.GroupContainer =
            SharedConfig.appGroupID.isEmpty ? .automatic : .identifier(SharedConfig.appGroupID)

        // Preferred: iCloud sync on top of the shared App Group store.
        if !SharedConfig.cloudContainerID.isEmpty {
            let cloud = ModelConfiguration(
                schema: schema,
                groupContainer: group,
                cloudKitDatabase: .private(SharedConfig.cloudContainerID)
            )
            do {
                return try ModelContainer(for: schema, configurations: cloud)
            } catch {
                SharedConfig.logger.error("iCloud store unavailable, falling back to local: \(error.localizedDescription)")
            }
        }

        // Fallback: local-only (e.g. builds signed without iCloud entitlements).
        let local = ModelConfiguration(schema: schema, groupContainer: group, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            SharedConfig.logger.fault("Local store unavailable, using in-memory store: \(error.localizedDescription)")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // In-memory creation only fails if the schema itself is invalid, which is a programmer error.
            return try! ModelContainer(for: schema, configurations: memory)
        }
    }
}
