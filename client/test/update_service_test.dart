import 'package:flutter_test/flutter_test.dart';
import 'package:wisplit_client/core/services/update_service.dart';

void main() {
  group('UpdateService Version Comparison', () {
    test('compares identical versions', () {
      expect(UpdateService.compareVersions('1.0.8', '1.0.8'), 0);
      expect(UpdateService.compareVersions('v1.0.8', '1.0.8'), 0);
      expect(UpdateService.compareVersions('V1.0.8', 'v1.0.8'), 0);
    });

    test('detects newer minor and patch versions', () {
      expect(UpdateService.compareVersions('1.0.9', '1.0.8'), 1);
      expect(UpdateService.compareVersions('v1.0.10', '1.0.9'), 1);
      expect(UpdateService.compareVersions('v1.1.0', '1.0.9'), 1);
      expect(UpdateService.compareVersions('2.0.0', '1.9.9'), 1);
    });

    test('detects older versions', () {
      expect(UpdateService.compareVersions('1.0.7', '1.0.8'), -1);
      expect(UpdateService.compareVersions('v1.0.8', '1.0.9'), -1);
      expect(UpdateService.compareVersions('1.0.0', '2.0.0'), -1);
    });
  });
}
