import CoreTransferable
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Headline numbers from the study log, worked out on the phone. Everything comes from the
/// event log, so it only covers the time since the participant agreed to take part.
struct StudySummary {
    var since: Date?
    var days = 0
    var timersStarted = 0
    var startedFromLockScreen = 0
    var averageRequested = 0
    var minutesUsed = 0
    var limitsReached = 0
    var brokenDuringBreak = 0
    /// "Not now" or "Keep my promise" on the lock screen: opened a locked app and backed out.
    var backedOut = 0

    var minutesPerDay: Int { days > 0 ? minutesUsed / days : 0 }
    /// Timers that ended without the promise being broken by unlocking during the break.
    var kept: Int { max(0, finished - brokenDuringBreak) }
    var keptPercent: Int? { finished > 0 ? Int((Double(kept) / Double(finished) * 100).rounded()) : nil }
    fileprivate var finished = 0

    init(events: [LoggedEvent], now: Date = .now, calendar: Calendar = .current) {
        since = events.first { $0.type == .consentGiven }?.timestamp ?? events.first?.timestamp
        if let since {
            let span = calendar.dateComponents([.day], from: calendar.startOfDay(for: since), to: calendar.startOfDay(for: now)).day ?? 0
            days = span + 1
        }
        var requestedTotal = 0
        for event in events {
            switch event.type {
            case .sessionStarted:
                timersStarted += 1
                requestedTotal += event.minutes ?? 0
            case .sessionRequested where event.detail == "lock_screen":
                startedFromLockScreen += 1
            case .sessionEnded where event.detail != "authorization_lost":
                // Ended early or by the backstop window. Timers that ran out log limitReached instead.
                finished += 1
                minutesUsed += event.minutes ?? 0
            case .limitReached:
                // Logged with the full time asked for, which is the time used.
                finished += 1
                limitsReached += 1
                minutesUsed += event.minutes ?? 0
            case .brokeDuringBreak:
                brokenDuringBreak += 1
            case .shieldButtonTapped:
                let detail = event.detail ?? ""
                if detail.hasPrefix("primary,") || detail.hasPrefix("not_now,") { backedOut += 1 }
            default:
                break
            }
        }
        averageRequested = timersStarted > 0 ? requestedTotal / timersStarted : 0
    }
}

/// One row per day of the study, for a spreadsheet.
enum DailySummaryCSV {
    static let columns = ["participant_id", "group", "date", "timers_started", "minutes_used", "limits_reached",
                          "broke_during_break", "backed_out_on_lock_screen"]

    static func csv(events: [LoggedEvent], participantID: String, group: StudyGroup,
                    now: Date = .now, calendar: Calendar = .current) -> String {
        var lines = [columns.joined(separator: ",")]
        guard let first = events.first?.timestamp else { return lines.joined(separator: "\n") + "\n" }
        var day = calendar.startOfDay(for: first)
        while day <= now {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let summary = StudySummary(events: events.filter { $0.timestamp >= day && $0.timestamp < next })
            lines.append([
                participantID, group.rawValue, DayKey.string(for: day),
                "\(summary.timersStarted)", "\(summary.minutesUsed)", "\(summary.limitsReached)",
                "\(summary.brokenDuringBreak)", "\(summary.backedOut)",
            ].joined(separator: ","))
            day = next
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Lets `ShareLink` build the daily file only when it's actually shared.
struct DailySummaryExport: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { _ in
            let study = SharedStore.load().study
            let id = study.participantID.isEmpty ? "unenrolled" : study.participantID
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("accountable-daily-\(id.filter { $0.isLetter || $0.isNumber })-\(DayKey.string(for: .now)).csv")
            try DailySummaryCSV.csv(events: EventLog.all(), participantID: id, group: study.group)
                .write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}

struct StudySummaryView: View {
    @State private var summary = StudySummary(events: EventLog.all())

    var body: some View {
        Form {
            Section {
                if let since = summary.since {
                    LabeledContent("Logging since", value: since.formatted(date: .abbreviated, time: .omitted))
                }
                LabeledContent("Days", value: "\(summary.days)")
            }
            Section("Timers") {
                LabeledContent("Started", value: "\(summary.timersStarted)")
                LabeledContent("From the lock screen", value: "\(summary.startedFromLockScreen)")
                LabeledContent("Average asked for", value: "\(summary.averageRequested) min")
            }
            Section("Promises") {
                LabeledContent("Kept", value: summary.keptPercent.map { "\(summary.kept) (\($0)%)" } ?? "—")
                LabeledContent("Time ran out", value: "\(summary.limitsReached)")
                LabeledContent("Unlocked during a break", value: "\(summary.brokenDuringBreak)")
                LabeledContent("Backed out at the lock screen", value: "\(summary.backedOut)")
            }
            Section {
                LabeledContent("Minutes in the apps", value: "\(summary.minutesUsed)")
                LabeledContent("Per day", value: "\(summary.minutesPerDay) min")
            } header: {
                Text("Time")
            } footer: {
                Text("Only time during timers counts, since the apps are locked the rest of the time. \"Backed out\" counts taps on Not now or Keep my promise; closing the lock screen without tapping isn't recorded.")
            }
        }
        .navigationTitle("Study summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { summary = StudySummary(events: EventLog.all()) }
    }
}
