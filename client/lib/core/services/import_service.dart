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
  final bool isPayment;

  const ImportedExpenseRow({
    required this.description,
    required this.amount,
    required this.paidBy,
    this.splitType = 'EQUAL',
    this.date,
    this.participants = const [],
    this.isPayment = false,
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

    int headerIdx = -1;
    // Identify header row
    for (int i = 0; i < rows.length; i++) {
      final lineJoined = rows[i].join(' ').toLowerCase();
      if (lineJoined.contains('description') ||
          lineJoined.contains('amount') ||
          lineJoined.contains('paid') ||
          lineJoined.contains('spend') ||
          lineJoined.contains('payment')) {
        headerIdx = i;
        break;
      }
    }

    // Column indices mapping
    int dateIdx = 0;
    int descIdx = 1;
    int paidByIdx = 2;
    int amountIdx = 3;
    int splitIdx = 4;
    int participantsIdx = 5;
    int typeIdx = -1;

    if (headerIdx != -1) {
      final headerCols = rows[headerIdx];
      int foundDate = -1;
      int foundDesc = -1;
      int foundPaid = -1;
      int foundAmt = -1;
      int foundSplit = -1;
      int foundParts = -1;
      int foundType = -1;

      for (int c = 0; c < headerCols.length; c++) {
        final colName = headerCols[c].trim().toLowerCase();
        if (colName.contains('date') || colName.contains('time')) {
          foundDate = c;
        } else if (colName == 'type' || colName.contains('category') || colName.contains('kind')) {
          foundType = c;
        } else if (colName.contains('description') || colName.contains('desc') || colName.contains('note') || colName.contains('title')) {
          foundDesc = c;
        } else if (colName.contains('paid by') || colName.contains('payer') || colName.contains('who paid') || colName == 'paid') {
          foundPaid = c;
        } else if (colName.contains('amount') || colName.contains('inr') || colName.contains('cost') || colName.contains('total') || colName.contains('price')) {
          foundAmt = c;
        } else if (colName.contains('split') || colName.contains('method')) {
          foundSplit = c;
        } else if (colName.contains('participant') || colName.contains('member') || colName.contains('shared') || colName.contains('with') || colName == 'to' || colName == 'paid to') {
          foundParts = c;
        }
      }

      if (foundDesc != -1) descIdx = foundDesc;
      if (foundPaid != -1) paidByIdx = foundPaid;
      if (foundAmt != -1) amountIdx = foundAmt;
      if (foundDate != -1) dateIdx = foundDate;
      if (foundSplit != -1) splitIdx = foundSplit;
      if (foundParts != -1) participantsIdx = foundParts;
      if (foundType != -1) typeIdx = foundType;
    }

    final startIdx = headerIdx != -1 ? headerIdx + 1 : 0;

    for (int i = startIdx; i < rows.length; i++) {
      final cols = rows[i];
      if (cols.length < 3) continue;

      try {
        DateTime? date = (dateIdx >= 0 && dateIdx < cols.length) ? _parseDate(cols[dateIdx]) : null;
        String description = (descIdx >= 0 && descIdx < cols.length) ? cols[descIdx].trim() : '';
        String paidBy = (paidByIdx >= 0 && paidByIdx < cols.length) ? cols[paidByIdx].trim() : '';
        double amount = (amountIdx >= 0 && amountIdx < cols.length) ? _parseAmount(cols[amountIdx]) : 0.0;
        String splitType = (splitIdx >= 0 && splitIdx < cols.length && cols[splitIdx].trim().isNotEmpty)
            ? cols[splitIdx].trim().toUpperCase()
            : 'EQUAL';
        String typeVal = (typeIdx >= 0 && typeIdx < cols.length) ? cols[typeIdx].trim().toLowerCase() : '';
        List<String> participants = [];
        if (participantsIdx >= 0 && participantsIdx < cols.length && cols[participantsIdx].trim().isNotEmpty) {
          participants = cols[participantsIdx]
              .split(RegExp(r'[;,]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        if (amount < 0) {
          amount = amount.abs();
        }
        if (amount == 0) continue;
        if (description.isEmpty) {
          description = typeVal.isNotEmpty ? typeVal : 'Expense';
        }
        if (paidBy.isEmpty) {
          paidBy = 'You';
        }

        // Detect if row is a Payment or an Expense
        final isPayment = _detectIsPayment(description: description, splitType: splitType, typeValue: typeVal);

        result.add(ImportedExpenseRow(
          description: description,
          amount: amount,
          paidBy: paidBy,
          splitType: splitType.isNotEmpty ? splitType : 'EQUAL',
          date: date,
          participants: participants,
          isPayment: isPayment,
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

    final table = <List<String>>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('//')) continue;
      table.add(_splitCsvLine(trimmed, delimiter));
    }

    return parseTableRows(table);
  }

  /// Converts parsed rows into CreateExpenseRequest objects ready for the provider.
  /// Automatically distinguishes and formats both EXPENSES and PAYMENTS.
  static List<CreateExpenseRequest> toExpenseRequests(
    List<ImportedExpenseRow> rows,
    List<String> groupMembers,
  ) {
    return rows.map((row) {
      final payerResolved = _resolveMember(row.paidBy, groupMembers);

      // ── Payment Row: Record direct payment (e.g. A paid B ₹300) ───────────
      if (row.isPayment) {
        // Recipients: non-payers in row participants
        List<String> recipients = row.participants
            .map((p) => _resolveMember(p, groupMembers))
            .where((p) => p.toLowerCase() != payerResolved.toLowerCase())
            .toList();

        // If participants did not explicitly name the recipient, pick other group member(s)
        if (recipients.isEmpty) {
          recipients = groupMembers
              .where((m) => m.toLowerCase() != payerResolved.toLowerCase())
              .toList();
        }

        // Fallback for single-member groups
        if (recipients.isEmpty && groupMembers.isNotEmpty) {
          recipients = [groupMembers.first];
        }

        final toUserDisplay = recipients.isNotEmpty ? recipients.first : 'Member';
        final desc = (row.description.isEmpty || row.description.toLowerCase() == 'payment')
            ? 'Payment: $payerResolved → $toUserDisplay'
            : row.description;

        final share = recipients.isNotEmpty ? (row.amount / recipients.length) : row.amount;
        final splits = recipients.map((r) => SplitItemInput(userId: r, amount: share)).toList();

        return CreateExpenseRequest(
          paidBy: payerResolved,
          amount: row.amount,
          currency: 'INR',
          description: desc,
          splitType: SplitType.EXACT,
          splits: splits,
          createdAt: row.date,
        );
      }

      // ── Expense Row: Standard group split (EQUAL, EXACT, PERCENTAGE, etc.) ──
      final rawParticipants = row.participants.isNotEmpty
          ? row.participants.map((p) => _resolveMember(p, groupMembers)).toList()
          : groupMembers;
      final participants = rawParticipants.isNotEmpty ? rawParticipants : [payerResolved];

      final splitType = SplitType.fromJson(row.splitType);
      final splits = participants.map((uid) {
        return SplitItemInput(
          userId: uid,
          amount: row.amount / participants.length,
        );
      }).toList();

      return CreateExpenseRequest(
        paidBy: payerResolved,
        amount: row.amount,
        currency: 'INR',
        description: row.description.isNotEmpty ? row.description : 'Group Expense',
        splitType: splitType,
        splits: splits,
        createdAt: row.date,
      );
    }).toList();
  }

  /// Generates a sample CSV template string showing both Expenses and Payments.
  static String generateTemplate() {
    final buf = StringBuffer();
    buf.writeln('Date,Description,Paid By,Amount (INR),Split Method,Participants');
    buf.writeln('2026-10-27 19:30:00,Dinner at Bistro,Sanwi,1200.00,EQUAL,Amrit;Sanwi');
    buf.writeln('2026-10-27 20:15:00,Payment,Sanwi,2000.00,PAYMENT,Amrit;Sanwi');
    buf.writeln('2026-10-27 21:00:00,Groceries,Amrit,850.50,EQUAL,Amrit;Sanwi');
    buf.writeln('2026-10-27 22:30:00,Payment,Amrit,150.00,PAYMENT,Amrit;Sanwi');
    return buf.toString();
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  static bool _detectIsPayment({
    required String description,
    required String splitType,
    required String typeValue,
  }) {
    final lowerType = typeValue.trim().toLowerCase();
    final lowerDesc = description.trim().toLowerCase();
    final upperSplit = splitType.trim().toUpperCase();

    // 1. Explicit Type column
    if (lowerType == 'payment' || lowerType == 'settle' || lowerType == 'settlement' || lowerType == 'transfer') {
      return true;
    }

    // 2. Split Method specified as PAYMENT or SETTLE
    if (upperSplit == 'PAYMENT' || upperSplit == 'SETTLE' || upperSplit == 'SETTLEMENT') {
      return true;
    }

    // 3. Description is "Payment" (as in screenshot) or starts with payment / settle
    if (lowerDesc == 'payment' ||
        lowerDesc.startsWith('payment ') ||
        lowerDesc.startsWith('payment:') ||
        lowerDesc.startsWith('settle') ||
        lowerDesc.startsWith('paid to ')) {
      return true;
    }

    return false;
  }

  static String _resolveMember(String rawName, List<String> groupMembers) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return trimmed;

    // 1. Exact match (case-insensitive)
    for (final m in groupMembers) {
      if (m.toLowerCase() == trimmed.toLowerCase()) return m;
    }

    // 2. Starts with / contains match (e.g. "Amrit" matches "Amritanshu" or "amrit@...")
    for (final m in groupMembers) {
      if (m.toLowerCase().startsWith(trimmed.toLowerCase()) ||
          trimmed.toLowerCase().startsWith(m.toLowerCase())) {
        return m;
      }
    }

    // 3. Fallback to raw string
    return trimmed;
  }

  static double _parseAmount(String raw) {
    // Strip currency symbols (₹, $, €, £) and currency words (INR, Rs., Rs, USD, EUR)
    var cleaned = raw
        .replaceAll(RegExp(r'(₹|\$|€|£|INR|Rs\.|Rs|USD|EUR)', caseSensitive: false), '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
      cleaned = '-${cleaned.substring(1, cleaned.length - 1)}';
    }
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
