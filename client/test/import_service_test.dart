import 'package:flutter_test/flutter_test.dart';
import 'package:wisplit_client/core/services/import_service.dart';
import 'package:wisplit_client/data/models/expense_models.dart';

void main() {
  group('ImportService Tests', () {
    test('parses mixed sheet with payments and expenses simultaneously', () {
      const csvData = '''
Date,Description,Paid By,Amount (INR),Split Method,Participants
2026-09-02 0:00:00,Payment,Sanwi,2000,EQUAL,Amrit;Sanwi
2026-09-02 12:00:00,Dinner at Bistro,Sanwi,1200,EQUAL,Amrit;Sanwi
2026-09-03 0:00:00,Payment,Amrit,150,EQUAL,Amrit;Sanwi
2026-09-04 15:30:00,Groceries,Amrit,500,EQUAL,Amrit;Sanwi
''';

      final rows = ImportService.parseContent(csvData);
      expect(rows.length, 4);

      // Verify row classification
      expect(rows[0].isPayment, isTrue);
      expect(rows[0].description, 'Payment');
      expect(rows[0].paidBy, 'Sanwi');
      expect(rows[0].amount, 2000.0);

      expect(rows[1].isPayment, isFalse);
      expect(rows[1].description, 'Dinner at Bistro');
      expect(rows[1].amount, 1200.0);

      expect(rows[2].isPayment, isTrue);
      expect(rows[2].description, 'Payment');
      expect(rows[2].paidBy, 'Amrit');
      expect(rows[2].amount, 150.0);

      expect(rows[3].isPayment, isFalse);
      expect(rows[3].description, 'Groceries');

      // Convert to CreateExpenseRequests
      final requests = ImportService.toExpenseRequests(rows, ['Amrit', 'Sanwi']);
      expect(requests.length, 4);

      // 1. Sanwi paid Amrit 2000
      final p1 = requests[0];
      expect(p1.paidBy, 'Sanwi');
      expect(p1.amount, 2000.0);
      expect(p1.splitType, SplitType.EXACT);
      expect(p1.splits.length, 1);
      expect(p1.splits[0].userId, 'Amrit');
      expect(p1.splits[0].amount, 2000.0);
      expect(p1.description, 'Payment: Sanwi → Amrit');

      // 2. Dinner expense 1200 split equally
      final e1 = requests[1];
      expect(e1.paidBy, 'Sanwi');
      expect(e1.amount, 1200.0);
      expect(e1.splitType, SplitType.EQUAL);
      expect(e1.splits.length, 2);
      expect(e1.splits[0].amount, 600.0);
      expect(e1.splits[1].amount, 600.0);
      expect(e1.description, 'Dinner at Bistro');

      // 3. Amrit paid Sanwi 150
      final p2 = requests[2];
      expect(p2.paidBy, 'Amrit');
      expect(p2.amount, 150.0);
      expect(p2.splitType, SplitType.EXACT);
      expect(p2.splits.length, 1);
      expect(p2.splits[0].userId, 'Sanwi');
      expect(p2.splits[0].amount, 150.0);
      expect(p2.description, 'Payment: Amrit → Sanwi');

      // 4. Groceries expense 500 split equally
      final e2 = requests[3];
      expect(e2.paidBy, 'Amrit');
      expect(e2.amount, 500.0);
      expect(e2.splitType, SplitType.EQUAL);
      expect(e2.splits.length, 2);
    });

    test('supports Split Method PAYMENT explicitly', () {
      const csvData = '''
Date,Description,Paid By,Amount (INR),Split Method,Participants
2026-10-27 20:15:00,UPI Settle Up,Sanwi,500.00,PAYMENT,Amrit
''';
      final rows = ImportService.parseContent(csvData);
      expect(rows.length, 1);
      expect(rows[0].isPayment, isTrue);

      final requests = ImportService.toExpenseRequests(rows, ['Amrit', 'Sanwi']);
      expect(requests[0].paidBy, 'Sanwi');
      expect(requests[0].splitType, SplitType.EXACT);
      expect(requests[0].splits[0].userId, 'Amrit');
      expect(requests[0].splits[0].amount, 500.0);
    });

    test('handles formatted amounts with currency symbols and negative values', () {
      const csvData = '''
Date,Description,Paid By,Amount
2026-10-27,Coffee,Sanwi,₹150.00
2026-10-27,Dinner,,"Rs. 1,200.50"
2026-10-27,Refund,Amrit,-300.00
2026-10-27,Adjustment,Sanwi,(450.00)
''';
      final rows = ImportService.parseContent(csvData);
      expect(rows.length, 4);
      expect(rows[0].amount, 150.0);
      expect(rows[1].amount, 1200.50);
      expect(rows[1].paidBy, 'You'); // Fallback for missing payer
      expect(rows[2].amount, 300.0); // Negative converted to absolute
      expect(rows[3].amount, 450.0); // Parentheses converted to absolute
    });
  });
}
