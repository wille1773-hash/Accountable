import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Turns the event log into a CSV file for the share sheet.
enum CSVExporter {
    static let columns = ["participant_id", "group", "event", "timestamp", "minutes", "session_id", "detail", "logged_at"]

    static func csv(events: [LoggedEvent], participantID: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        var lines = [columns.joined(separator: ",")]
        for event in events {
            let fields = [
                participantID,
                event.group.rawValue,
                event.type.rawValue,
                formatter.string(from: event.timestamp),
                event.minutes.map(String.init) ?? "",
                event.sessionID ?? "",
                event.detail ?? "",
                formatter.string(from: event.loggedAt),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Writes the CSV to a temporary file and returns its URL.
    static func writeFile() throws -> URL {
        let state = SharedStore.load()
        let id = state.study.participantID.isEmpty ? "unenrolled" : state.study.participantID
        let date = DayKey.string(for: .now)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("accountable-\(safe(id))-\(date).csv")
        try csv(events: EventLog.all(), participantID: id).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func safe(_ s: String) -> String {
        String(s.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
    }
}

/// Lets `ShareLink` build the file only when the participant actually shares it.
struct EventLogExport: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { _ in
            SentTransferredFile(try CSVExporter.writeFile())
        }
    }
}
