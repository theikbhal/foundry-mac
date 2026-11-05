import Foundation
import SQLite3

enum SQLValue: Hashable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    var jsonValue: JSONValue {
        switch self {
        case .null: return .null
        case .integer(let value): return .number(Double(value))
        case .real(let value): return .number(value)
        case .text(let value): return .string(value)
        case .blob(let data): return .string("<\(data.count) byte blob>")
        }
    }

    var display: String {
        switch self {
        case .null: return ""
        case .integer(let value): return String(value)
        case .real(let value): return JSONValue.formatNumber(value)
        case .text(let value): return value
        case .blob(let data): return "<\(data.count) bytes>"
        }
    }

    var stringValue: String? {
        switch self {
        case .null: return nil
        case .integer(let value): return String(value)
        case .real(let value): return JSONValue.formatNumber(value)
        case .text(let value): return value
        case .blob: return nil
        }
    }

    var intValue: Int64? {
        switch self {
        case .integer(let value): return value
        case .real(let value): return Int64(value)
        case .text(let value): return Int64(value)
        case .null, .blob: return nil
        }
    }

    var sqlLiteral: String {
        switch self {
        case .null: return "NULL"
        case .integer(let value): return String(value)
        case .real(let value):
            guard value.isFinite else { return "NULL" }
            return JSONValue.formatNumber(value)
        case .text(let value):
            return "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
        case .blob(let data):
            return "X'" + data.map { String(format: "%02X", $0) }.joined() + "'"
        }
    }
}

struct SQLiteColumn: Codable, Hashable, Identifiable {
    var name: String
    var type: String
    var notNull: Bool
    var primaryKey: Bool
    var id: String { name }
}

struct SQLiteTable: Codable, Hashable, Identifiable {
    var name: String
    var kind: String
    var rowCount: Int
    var columns: [SQLiteColumn]
    var id: String { name }
}

struct SQLiteResult {
    var columns: [String] = []
    var rows: [[SQLValue]] = []
    var affectedRows: Int = 0
    var lastInsertRowID: Int64 = 0

    var objectRows: [JSONValue] {
        rows.map { row in
            var object: [String: JSONValue] = [:]
            for (index, column) in columns.enumerated() where index < row.count {
                object[column] = row[index].jsonValue
            }
            return .object(object)
        }
    }
}

struct SQLiteFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

enum SQLiteEngine {
    static func query(_ sql: String, path: String, readOnly: Bool = false) throws -> SQLiteResult {
        let db = try open(path, readOnly: readOnly)
        defer { sqlite3_close(db) }

        var result = SQLiteResult()
        var remaining = sql

        for _ in 0..<256 {
            let statement = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            if statement.isEmpty { break }

            var stmt: OpaquePointer?
            var nextSQL = ""
            let prepareResult = statement.withCString { pointer -> Int32 in
                var tail: UnsafePointer<CChar>?
                let code = sqlite3_prepare_v2(db, pointer, -1, &stmt, &tail)
                if let tail { nextSQL = String(cString: tail) }
                return code
            }

            if prepareResult != SQLITE_OK {
                throw SQLiteFailure(message: String(cString: sqlite3_errmsg(db)))
            }
            guard let stmt else { break }

            let columnCount = Int(sqlite3_column_count(stmt))
            if columnCount > 0 {
                var columns: [String] = []
                for index in 0..<columnCount {
                    columns.append(String(cString: sqlite3_column_name(stmt, Int32(index))))
                }
                var rows: [[SQLValue]] = []
                while true {
                    let step = sqlite3_step(stmt)
                    if step == SQLITE_ROW {
                        var row: [SQLValue] = []
                        row.reserveCapacity(columnCount)
                        for index in 0..<columnCount {
                            row.append(readColumn(stmt, Int32(index)))
                        }
                        rows.append(row)
                    } else if step == SQLITE_DONE {
                        break
                    } else {
                        let message = String(cString: sqlite3_errmsg(db))
                        sqlite3_finalize(stmt)
                        throw SQLiteFailure(message: message)
                    }
                }
                result.columns = columns
                result.rows = rows
            } else {
                let step = sqlite3_step(stmt)
                if step != SQLITE_DONE && step != SQLITE_ROW {
                    let message = String(cString: sqlite3_errmsg(db))
                    sqlite3_finalize(stmt)
                    throw SQLiteFailure(message: message)
                }
            }

            sqlite3_finalize(stmt)

            if nextSQL == statement { break }
            remaining = nextSQL
        }

        result.affectedRows = Int(sqlite3_changes(db))
        result.lastInsertRowID = sqlite3_last_insert_rowid(db)
        return result
    }

    static func tables(at path: String) throws -> [SQLiteTable] {
        let list = try query(
            "SELECT name, type FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' ORDER BY name COLLATE NOCASE;",
            path: path,
            readOnly: true
        )

        var tables: [SQLiteTable] = []
        for row in list.rows {
            guard row.count >= 2 else { continue }
            let name = row[0].stringValue ?? ""
            let kind = row[1].stringValue ?? "table"
            if name.isEmpty { continue }
            let quoted = quoteIdentifier(name)

            var columns: [SQLiteColumn] = []
            if kind == "table", let info = try? query("PRAGMA table_info(\(quoted));", path: path, readOnly: true) {
                for row in info.rows {
                    let columnName = row.count > 1 ? (row[1].stringValue ?? "") : ""
                    let columnType = row.count > 2 ? (row[2].stringValue ?? "") : ""
                    let notNull = row.count > 3 ? ((row[3].intValue ?? 0) != 0) : false
                    let primaryKey = row.count > 5 ? ((row[5].intValue ?? 0) != 0) : false
                    columns.append(SQLiteColumn(name: columnName, type: columnType, notNull: notNull, primaryKey: primaryKey))
                }
            }

            var rowCount = 0
            if let countResult = try? query("SELECT COUNT(*) FROM \(quoted);", path: path, readOnly: true),
               let value = countResult.rows.first?.first?.intValue {
                rowCount = Int(value)
            }

            tables.append(SQLiteTable(name: name, kind: kind, rowCount: rowCount, columns: columns))
        }
        return tables
    }

    static func createDatabase(at path: String, seedSQL: String?) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try query("SELECT 1;", path: path)
        if let seedSQL, !seedSQL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = try query(seedSQL, path: path)
        }
    }

    static func dump(at path: String, includeData: Bool = true, maxRowsPerTable: Int = 5000) throws -> String {
        let tables = try tables(at: path)
        var lines: [String] = ["PRAGMA foreign_keys=OFF;", "BEGIN TRANSACTION;"]

        for table in tables where table.kind == "table" {
            if let schemaResult = try? query(
                "SELECT sql FROM sqlite_master WHERE type='table' AND name=\(quoteString(table.name));",
                path: path,
                readOnly: true
            ), let schema = schemaResult.rows.first?.first?.stringValue {
                if schema.uppercased().hasPrefix("CREATE VIRTUAL") { continue }
                lines.append(schema + ";")
            }

            guard includeData, table.rowCount > 0 else { continue }
            let data = try query(
                "SELECT * FROM \(quoteIdentifier(table.name)) LIMIT \(maxRowsPerTable);",
                path: path,
                readOnly: true
            )
            let columnList = data.columns.map { quoteIdentifier($0) }.joined(separator: ", ")
            for row in data.rows {
                let values = row.map { $0.sqlLiteral }.joined(separator: ", ")
                lines.append("INSERT INTO \(quoteIdentifier(table.name)) (\(columnList)) VALUES (\(values));")
            }
        }

        lines.append("COMMIT;")
        return lines.joined(separator: "\n")
    }

    static func quoteIdentifier(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func quoteString(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }

    private static func open(_ path: String, readOnly: Bool) throws -> OpaquePointer {
        var handle: OpaquePointer?
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        let code = sqlite3_open_v2(path, &handle, flags, nil)
        guard code == SQLITE_OK, let handle else {
            let message = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Could not open database at \(path)"
            if let handle { sqlite3_close(handle) }
            throw SQLiteFailure(message: message)
        }
        sqlite3_busy_timeout(handle, 3000)
        return handle
    }

    private static func readColumn(_ statement: OpaquePointer, _ index: Int32) -> SQLValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            if let text = sqlite3_column_text(statement, index) {
                return .text(String(cString: text))
            }
            return .text("")
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, index))
            if let bytes = sqlite3_column_blob(statement, index), count > 0 {
                return .blob(Data(bytes: bytes, count: count))
            }
            return .blob(Data())
        default:
            return .null
        }
    }
}
