import Foundation

/// Matches snapshot entries against an iOS autofill service identifier
/// (a web domain). Mirrors the Dart `AutofillMatcher` ranking: exact host wins,
/// subdomain/parent-domain overlap ranks below exact matches.
enum Matcher {
    struct Candidate {
        let entry: SnapshotStore.Entry
        let score: Int
    }

    static func match(_ snapshot: SnapshotStore.Snapshot, domain: String?) -> [Candidate] {
        let d = domain?.lowercased()
        var scored: [Candidate] = []
        for e in snapshot.entries {
            var best = 0
            if let d = d {
                for host in e.domains {
                    let h = host.lowercased()
                    if h == d {
                        best = max(best, 100)
                    } else if d.hasSuffix("." + h) || h.hasSuffix("." + d) {
                        best = max(best, 60)
                    }
                }
            }
            if best == 0 { continue }
            scored.append(Candidate(entry: e, score: best))
        }
        scored.sort { $0.score > $1.score }
        return scored
    }
}
