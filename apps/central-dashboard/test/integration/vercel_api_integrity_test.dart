// ignore_for_file: avoid_print
// Integrity Tests — Vercel CRM API Connectivity and Lead Uploading
//
// Verifies the connection to the remote Vercel CRM API, checking authentication
// logic (valid/invalid tokens) and the correct uploading/duplicate detection of leads.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:centralny_dashboard/core/config/config.dart';

class TestHttpOverrides extends HttpOverrides {}

void main() {
  // Ensure we can make real HTTP requests during testing
  HttpOverrides.runWithHttpOverrides(() {
    group('Vercel CRM API Integrity', () {
      final String crmBaseUrl = AppConfig.crmFrameUrl.replaceAll('/crm', '');
      final String leadsApiUrl = '$crmBaseUrl/api/crm/leads';

      // Live authenticated checks are opt-in and require a token at compile time.
      const String crmToken = String.fromEnvironment(
        'CRM_AUTH_TOKEN',
        defaultValue: '',
      );
      const bool runLiveCrmTests = bool.fromEnvironment(
        'RUN_LIVE_CRM_INTEGRITY_TESTS',
        defaultValue: false,
      );
      final liveTestSkipReason = runLiveCrmTests && crmToken.isNotEmpty
          ? false
          : 'Set RUN_LIVE_CRM_INTEGRITY_TESTS=true and CRM_AUTH_TOKEN.';

      print('Testing CRM API at: $leadsApiUrl');

      test(
        'Unauthenticated request to leads endpoint returns 401 Unauthorized',
        () async {
          final client = HttpClient();
          try {
            final request = await client.getUrl(Uri.parse(leadsApiUrl));
            // No header or invalid token should cause 401
            request.headers.add('x-crm-token', 'invalid-token-1234');

            final response = await request.close();
            print('Unauthenticated status code: ${response.statusCode}');

            final responseBody = await response.transform(utf8.decoder).join();
            expect(response.statusCode, HttpStatus.unauthorized);

            final data = jsonDecode(responseBody);
            expect(data['error'], contains('CRM auth token missing'));
          } finally {
            client.close();
          }
        },
        skip: liveTestSkipReason,
      );

      test(
        'Authenticated request returns 200 OK and valid leads structure',
        () async {
          final client = HttpClient();
          try {
            final request = await client.getUrl(Uri.parse(leadsApiUrl));
            request.headers.add('x-crm-token', crmToken);

            final response = await request.close();
            print('Authenticated status code: ${response.statusCode}');

            final responseBody = await response.transform(utf8.decoder).join();
            expect(response.statusCode, HttpStatus.ok);

            final data = jsonDecode(responseBody);
            expect(data, isMap);
            expect(data['leads'], isList);

            final leads = data['leads'] as List;
            print(
              'Successfully fetched ${leads.length} leads from Vercel CRM API.',
            );
          } finally {
            client.close();
          }
        },
        skip: liveTestSkipReason,
      );

      test(
        'Uploading a new lead works and duplicate leads are rejected',
        () async {
          final client = HttpClient();
          final uniqueId = DateTime.now().millisecondsSinceEpoch;
          final companyName = 'Integrity Test Company $uniqueId';

          try {
            // 1. Create a new unique lead
            final postRequest = await client.postUrl(Uri.parse(leadsApiUrl));
            postRequest.headers.add('x-crm-token', crmToken);
            postRequest.headers.contentType = ContentType.json;

            final leadPayload = {
              'company': companyName,
              'website': 'https://integrity-test-$uniqueId.com',
              'notes':
                  'Automated integrity test lead uploaded by Flutter test suite.',
              'status': 'new',
            };

            postRequest.write(jsonEncode(leadPayload));
            final postResponse = await postRequest.close();
            print('Post status code: ${postResponse.statusCode}');

            final postBody = await postResponse.transform(utf8.decoder).join();

            expect(postResponse.statusCode, HttpStatus.created); // 201 Created
            final postData = jsonDecode(postBody);
            expect(postData['lead'], isNotNull);
            expect(postData['lead']['company'], companyName);

            print('Successfully uploaded test lead for "$companyName".');

            // 2. Attempt to upload the exact same lead again to test duplicate handling (409 Conflict)
            final dupRequest = await client.postUrl(Uri.parse(leadsApiUrl));
            dupRequest.headers.add('x-crm-token', crmToken);
            dupRequest.headers.contentType = ContentType.json;
            dupRequest.write(jsonEncode(leadPayload));

            final dupResponse = await dupRequest.close();
            print('Dup status code: ${dupResponse.statusCode}');

            final dupBody = await dupResponse.transform(utf8.decoder).join();

            expect(dupResponse.statusCode, HttpStatus.conflict); // 409 Conflict

            final dupData = jsonDecode(dupBody);
            expect(dupData['error'], 'DUPLICATE_LEAD');
            expect(
              dupData['message'],
              contains('A matching lead already exists.'),
            );

            print(
              'Duplicate lead upload was correctly rejected with 409 Conflict.',
            );
          } finally {
            client.close();
          }
        },
        skip: liveTestSkipReason,
      );
    });
  }, TestHttpOverrides());
}
