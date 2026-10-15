import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:creative/engine/api_key_validator.dart';
import 'package:creative/engine/llm_provider.dart';

void main() {
  http.Client replying(int status, {void Function(http.Request)? onRequest}) =>
      MockClient((request) async {
        onRequest?.call(request);
        return http.Response('{}', status);
      });

  group('LiveApiKeyValidator', () {
    test('an empty key is reported as empty without any request', () async {
      var requests = 0;
      final validator = LiveApiKeyValidator(
        httpClient: replying(200, onRequest: (_) => requests++),
      );

      final result = await validator.validate('   ');

      expect(result.status, KeyCheckStatus.empty);
      expect(requests, 0);
    });

    test('an Anthropic key is flagged unsupported without any request', () async {
      var requests = 0;
      final validator = LiveApiKeyValidator(
        httpClient: replying(200, onRequest: (_) => requests++),
      );

      final result = await validator.validate('sk-ant-api03-abc');

      expect(result.status, KeyCheckStatus.unsupported);
      expect(requests, 0);
    });

    test('a key of unknown shape asks for a manual provider', () async {
      final validator = LiveApiKeyValidator(httpClient: replying(200));

      final result = await validator.validate('mystery-key');

      expect(result.status, KeyCheckStatus.undetected);
    });

    test('a Gemini key is checked against Gemini, sent in the header', () async {
      late http.Request seen;
      final validator = LiveApiKeyValidator(
        httpClient: replying(200, onRequest: (r) => seen = r),
      );

      final result = await validator.validate('AIzaSyExample');

      expect(result.status, KeyCheckStatus.valid);
      expect(result.provider, LlmProvider.gemini);
      expect(seen.url.host, 'generativelanguage.googleapis.com');
      expect(seen.headers['x-goog-api-key'], 'AIzaSyExample');
      // The key must never travel in the URL, where it ends up in logs.
      expect(seen.url.toString(), isNot(contains('AIzaSyExample')));
    });

    test('an OpenAI key is checked against OpenAI with a bearer token', () async {
      late http.Request seen;
      final validator = LiveApiKeyValidator(
        httpClient: replying(200, onRequest: (r) => seen = r),
      );

      final result = await validator.validate('  sk-proj-abc  ');

      expect(result.status, KeyCheckStatus.valid);
      expect(result.provider, LlmProvider.openai);
      expect(seen.url.host, 'api.openai.com');
      expect(seen.headers['authorization'], 'Bearer sk-proj-abc');
    });

    test('a manual provider overrides detection', () async {
      late http.Request seen;
      final validator = LiveApiKeyValidator(
        httpClient: replying(200, onRequest: (r) => seen = r),
      );

      // Looks like OpenAI, but the user says Gemini.
      final result = await validator.validate('sk-abc', provider: LlmProvider.gemini);

      expect(result.provider, LlmProvider.gemini);
      expect(seen.url.host, 'generativelanguage.googleapis.com');
    });

    test('a manual provider lets an unrecognized key be checked', () async {
      final validator = LiveApiKeyValidator(httpClient: replying(200));

      final result = await validator.validate('custom-key', provider: LlmProvider.openai);

      expect(result.status, KeyCheckStatus.valid);
    });

    for (final status in [400, 401, 403]) {
      test('a $status response means the key is invalid', () async {
        final validator = LiveApiKeyValidator(httpClient: replying(status));

        final result = await validator.validate('sk-abc');

        expect(result.status, KeyCheckStatus.invalid);
      });
    }

    test('a server error leaves the key unverified, not invalid', () async {
      final validator = LiveApiKeyValidator(httpClient: replying(503));

      final result = await validator.validate('sk-abc');

      expect(result.status, KeyCheckStatus.unverified);
    });

    test('a network failure leaves the key unverified, not invalid', () async {
      final validator = LiveApiKeyValidator(
        httpClient: MockClient((_) async => throw http.ClientException('no network')),
      );

      final result = await validator.validate('sk-abc');

      expect(result.status, KeyCheckStatus.unverified);
    });

    test('a timeout leaves the key unverified', () async {
      final validator = LiveApiKeyValidator(
        httpClient: MockClient((_) async => throw TimeoutException('slow')),
      );

      final result = await validator.validate('AIzaX');

      expect(result.status, KeyCheckStatus.unverified);
    });
  });
}
