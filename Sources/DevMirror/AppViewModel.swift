import Observation
import MirrorCore

@Observable
final class AppViewModel {
    var syncState = SyncState.idle
    var config = MirrorConfig.default
    var recentEvents: [SyncEvent] = []
}
