import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/firebase_options.dart';

void main() {
  test('Firebase options point to the expected project', () {
    expect(DefaultFirebaseOptions.currentPlatform.projectId, 'petcage-abb2f');
  });
}
