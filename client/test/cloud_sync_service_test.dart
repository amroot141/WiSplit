import 'package:flutter_test/flutter_test.dart';
import 'package:wisplit_client/data/models/group_model.dart';
import 'package:wisplit_client/data/services/cloud_sync_service.dart';

void main() {
  group('CloudSyncService Invite Code & Token Tests', () {
    test('formatInviteCode correctly creates 6-character code with WS- prefix', () {
      final code1 = CloudSyncService.formatInviteCode('e4d909c2-9b21-4d3e-8c5e-8b1e0f0a1b2c');
      expect(code1, 'WS-E4D909');

      final code2 = CloudSyncService.formatInviteCode('abc-123');
      expect(code2, 'WS-ABC123');

      final code3 = CloudSyncService.formatInviteCode('short');
      expect(code3, 'WS-SHORT');
    });

    test('normalizeCode removes WS- prefix, dashes, and extra spaces', () {
      expect(CloudSyncService.normalizeCode('WS-E4D909'), 'E4D909');
      expect(CloudSyncService.normalizeCode('ws-e4d909'), 'e4d909');
      expect(CloudSyncService.normalizeCode('  WS-8A9F-2B  '), '8A9F2B');
      expect(CloudSyncService.normalizeCode('8a9f'), '8a9f');
    });

    test('encodeGroupToken and decodeGroupToken correctly roundtrip group metadata', () {
      final now = DateTime.utc(2026, 10, 28, 14, 30);
      final original = GroupModel(
        id: 'test-group-id-123',
        name: 'Goa Trip 2026',
        description: 'Beach resort splitting',
        currency: 'INR',
        createdBy: 'user-amrit',
        members: ['Amrit', 'Rahul', 'Priya'],
        createdAt: now,
      );

      final token = CloudSyncService.encodeGroupToken(original);
      expect(token.startsWith('WS-T-'), isTrue);

      final decoded = CloudSyncService.decodeGroupToken(token);
      expect(decoded, isNotNull);
      expect(decoded!.id, original.id);
      expect(decoded.name, 'Goa Trip 2026');
      expect(decoded.description, 'Beach resort splitting');
      expect(decoded.currency, 'INR');
      expect(decoded.createdBy, 'user-amrit');
      expect(decoded.members, ['Amrit', 'Rahul', 'Priya']);
      expect(decoded.createdAt.isAtSameMomentAs(now), isTrue);
    });

    test('decodeGroupToken returns null on invalid or corrupted string', () {
      expect(CloudSyncService.decodeGroupToken('invalid-garbage'), isNull);
      expect(CloudSyncService.decodeGroupToken('WS-T-notbase64@@@'), isNull);
    });
  });
}
