import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';

import '../../data/models/expense_models.dart';

/// Parsed row from an imported spreadsheet or data file.
class ImportedExpenseRow {
  final String description;
  final double amount;
  final String paidBy;
  final String splitType;
  final DateTime? date;
  final List<String> participants;

  const ImportedExpenseRow({
    required this.description,
    required this.amount,
    required this.paidBy,
    this.splitType = 'EQUAL',
    this.date,
    this.participants = const [],
  });
}

class ImportService {
  /// Supported file extensions for import.
  static const List<String> supportedExtensions = ['xlsx', 'xls', 'csv', 'tsv', 'txt'];

  /// Parses raw file bytes (supporting Excel .xlsx/.xls as well as .csv/.tsv/.txt).
  static Future<List<ImportedExpenseRow>> parseFileBytes(Uint8List bytes, String filename) async {
    final ext = filename.split('.').last.toLowerCase();

    // 1. If it's an Excel spreadsheet, attempt binary Excel parsing
    if (ext == 'xlsx' || ext == 'xls') {
      try {
        final excel = Excel.decodeBytes(bytes);
        final allRows = <List<String>>[];

        for (final sheetName in excel.tables.keys) {
          final sheet = excel.tables[sheetName];
          if (sheet == null) continue;

          for (final row in sheet.rows) {
            final rowValues = row.map((cell) {
              if (cell == null || cell.value == null) return '';
              return cell.value.toString().trim();
            }).toList();

            // Skip empty rows
            if (rowValues.any((val) => val.isNotEmpty)) {
              allRows.add(rowValues);
            }
          }
        }

        if (allRows.isNotEmpty) {
          final parsed = parseTableRows(allRows);
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } catch (_) {
        // Fall back to text parsing if Excel binary decoding fails
        // (common when .xls files are actually exported CSVs or HTML tables)
      }
    }

    // 2. Text parsing for CSV, TSV, or TXT
    try {
      final text = utf8.decode(bytes, allowMalformed: true);
      return parseContent(text);
    } catch (_) {
      try {
        final text = latin1.decode(bytes);
        return parseContent(text);
      } catch (_) {
        return [];
      }
    }
  }

  /// Parses 2D list of cells extracted from an Excel sheet.
  static List<ImportedExpenseRow> parseTableRows(List<List<String>> rows) {
    final result = <ImportedExpenseRow>[];
    if (rows.isEmpty) return result;

    int startIdx = 0;
    // Identify header row
    for (int i = 0; i < rows.length; i++) {
      final lineJoined = rows[i].join(' ').toLowerCase();
      if (lineJoined.contains('description') ||
          lineJoined.contains('amount') ||
          lineJoined.contains('paid') ||
          lineJoined.contains('spend')) {
        startIdx = i + 1;
        break;
      }
    }

    for (int i = startIdx; i < rows.length; i++) {
      final cols = rows[i];
      if (cols.length < 3) continue;

      try {
        DateTime? date;
        String description;
        String paidBy;
        double amount;
        String splitType = 'EQUAL';
        List<String> participants = [];

        if (cols.length >= 4) {
          // Format: Date, Description, PaidBy, Amount, [SplitMethod], [Participants]
          date = _parseDate(cols[0]);
          description = cols[1].trim();
          paidBy = cols[2].trim();
          amount = _parseAmount(cols[3]);
          if (cols.length >= 5 && cols[4].trim().isNotEmpty) {
            splitType = cols[4].trim().toUpperCase();
          }
          if (cols.length >= 6 && cols[5].trim().isNotEmpty) {
            participants = cols[5]
                .split(RegExp(r'[;,]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } else {
          // Minimal format: Description, PaidBy, Amount
          description = cols[0].trim();
          paidBy = cols[1].trim();
          amount = _parseAmount(cols[2]);
        }

        if (amount <= 0 || description.isEmpty || paidBy.isEmpty) continue;

        result.add(ImportedExpenseRow(
          description: description,
          amount: amount,
          paidBy: paidBy,
          splitType: splitType.isNotEmpty ? splitType : 'EQUAL',
          date: date,
          participants: participants,
        ));
      } catch (_) {
        continue;
      }
    }

    return result;
  }

  /// Parses raw CSV/TSV text content into importable expense rows.
  static List<ImportedExpenseRow> parseContent(String rawContent) {
    final rows = <ImportedExpenseRow>[];
    if (rawContent.trim().isEmpty) return rows;

    // Detect delimiter: tab for TSV/XLS exports, comma for CSV, semicolon for European CSVs
    String delimiter = ',';
    final firstLine = rawContent.split('\n').first;
    if (firstLine.contains('\t')) {
      delimiter = '\t';
    } else if (firstLine.contains(';') && !firstLine.contains(',')) {
      delimiter = ';';
    }

    final lines = const LineSplitter().convert(rawContent);
    if (lines.isEmpty) return rows;

    // Skip header row and comment lines
    int startIdx = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) continue;
      final lower = line.toLowerCase();
      if (lower.contains('description') || lower.contains('amount') || lower.contains('paid')) {
        startIdx = i + 1;
        break;
      }
      startIdx = i;
      break;
    }

    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final cols = _splitCsvLine(line, delimiter);
      if (cols.length < 3) continue;

      try {
        DateTime? date;
        String description;
        String paidBy;
        double amount;
        String splitType = 'EQUAL';
        List<String> participants = [];

        if (cols.length >= 4) {
          date = _parseDate(cols[0].trim());
          description = cols[1].trim();
          paidBy = cols[2].trim();
          amount = _parseAmount(cols[3].trim());
          if (cols.length >= 5) splitType = cols[4].trim().toUpperCase();
          if (cols.length >= 6) {
            participants = cols[5]
                .trim()
                .split(';')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } else {
          description = cols[0].trim();
          paidBy = cols[1].trim();
          amount = _parseAmount(cols[2].trim());
        }

        if (amount <= 0 || description.isEmpty || paidBy.isEmpty) continue;

        rows.add(ImportedExpenseRow(
          description: description,
          amount: amount,
          paidBy: paidBy,
          splitType: splitType.isNotEmpty ? splitType : 'EQUAL',
          date: date,
          participants: participants,
        ));
      } catch (_) {
        continue;
      }
    }

    return rows;
  }

  /// Converts parsed rows into CreateExpenseRequest objects ready for the provider.
  static List<CreateExpenseRequest> toExpenseRequests(
    List<ImportedExpenseRow> rows,
    List<String> groupMembers,
  ) {
    return rows.map((row) {
      final participants = row.participants.isNotEmpty ? row.participants : groupMembers;
      final splitType = SplitType.fromJson(row.splitType);

      final splits = participants.map((uid) {
        return SplitItemInput(
          userId: uid,
          amount: row.amount / participants.length,
        );
      }).toList();

      return CreateExpenseRequest(
        paidBy: row.paidBy,
        amount: row.amount,
        currency: 'INR',
        description: row.description,
        splitType: splitType,
        splits: splits,
        createdAt: row.date,
      );
    }).toList();
  }

  /// Generates a sample CSV template string for download or copy.
  static String generateTemplate() {
    final buf = StringBuffer();
    buf.writeln('Date,Description,Paid By,Amount (INR),Split Method,Participants');
    buf.writeln('2026-10-27 19:30:00,Dinner at Bistro,user@email.com,1200.00,EQUAL,user1@email.com;user2@email.com');
    buf.writeln('2026-10-27 14:15:00,Groceries,user2@email.com,850.50,EQUAL,');
    return buf.toString();
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  static double _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[₹$,\s]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  static DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // ISO-8601 (e.g., 2026-10-27 or 2026-10-27T19:30:00)
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    // YYYY-MM-DD HH:MM:SS or YYYY-MM-DD HH:MM
    if (trimmed.contains(' ') && trimmed.contains('-')) {
      final isoCandidate = trimmed.replaceFirst(' ', 'T');
      final parsed = DateTime.tryParse(isoCandidate);
      if (parsed != null) return parsed;
    }

    // DD/MM/YYYY or DD/MM/YYYY HH:MM
    if (trimmed.contains('/')) {
      final parts = trimmed.split(' ');
      final dateParts = parts[0].split('/');
      if (dateParts.length == 3) {
        final d = int.tryParse(dateParts[0]);
        final m = int.tryParse(dateParts[1]);
        final y = int.tryParse(dateParts[2]);
        int h = 12;
        int min = 0;
        if (parts.length > 1) {
          final timeParts = parts[1].split(':');
          if (timeParts.isNotEmpty) h = int.tryParse(timeParts[0]) ?? 12;
          if (timeParts.length > 1) min = int.tryParse(timeParts[1]) ?? 0;
        }
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d, h, min);
        }
      }
    }

    // DD-MM-YYYY
    if (trimmed.contains('-')) {
      final parts = trimmed.split(' ');
      final dateParts = parts[0].split('-');
      if (dateParts.length == 3 && dateParts[0].length <= 2) {
        final d = int.tryParse(dateParts[0]);
        final m = int.tryParse(dateParts[1]);
        final y = int.tryParse(dateParts[2]);
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d);
        }
      }
    }

    return null;
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == delimiter && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString());

    return result;
  }
}
