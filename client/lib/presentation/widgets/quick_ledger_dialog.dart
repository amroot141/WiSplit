import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/personal_ledger_provider.dart';

/// Global navigator key allowing headless dialog presentation from MethodChannel
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Opens a basic, unstyled showDialog for fast personal ledger insertion
Future<void> showQuickLedgerDialog({
  BuildContext? context,
  required WidgetRef ref,
  required String currentUserId,
}) async {
  final targetContext = context ?? rootNavigatorKey.currentContext;
  if (targetContext == null) return;

  final amountController = TextEditingController();
  final friendController = TextEditingController();
  final descController = TextEditingController(text: 'Quick Tap Debt');
  bool iAmCreditor = true;

  await showDialog(
    context: targetContext,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Quick Personal Ledger Entry'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: friendController,
                    decoration: const InputDecoration(
                      labelText: "Friend's Name / ID",
                      hintText: 'e.g. Alex',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => iAmCreditor = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: iAmCreditor ? const Color(0xFFBFA2FA) : const Color(0x0FFFFFFF),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'They owe me',
                              style: TextStyle(
                                color: iAmCreditor ? const Color(0xFF250059) : Colors.white,
                                fontWeight: iAmCreditor ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => iAmCreditor = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !iAmCreditor ? const Color(0xFFBFA2FA) : const Color(0x0FFFFFFF),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'I owe them',
                              style: TextStyle(
                                color: !iAmCreditor ? const Color(0xFF250059) : Colors.white,
                                fontWeight: !iAmCreditor ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final parsedAmount = double.tryParse(amountController.text.trim());
                  final friend = friendController.text.trim();
                  final description = descController.text.trim();

                  if (parsedAmount == null || parsedAmount <= 0 || friend.isEmpty) {
                    return;
                  }

                  // Determine creditor and debtor IDs based on toggle
                  final creditorId = iAmCreditor ? currentUserId : friend;
                  final debtorId = iAmCreditor ? friend : currentUserId;

                  // Insert into offline-first local SQLite database & queue for sync
                  await ref.read(personalLedgerProvider.notifier).recordDebt(
                        creditorId: creditorId,
                        debtorId: debtorId,
                        amount: parsedAmount,
                        description: description.isEmpty ? 'Direct debt' : description,
                      );

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Add Entry'),
              ),
            ],
          );
        },
      );
    },
  );
}
