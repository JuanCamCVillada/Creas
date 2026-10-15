import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/engine/http_retry.dart';

Future<RetriedResponse> _post(
  http.Client client, {
  int maxRetries = 2,
  Duration timeout = const Duration(seconds: 5),
  bool Function(http.Response)? isTransient,
}) =>
    postWithRetry(
      client: client,
      url: Uri.parse('https://example.test/v1'),
      headers: const {},
      body: '{}',
      providerName: 'Prov',
      maxRetries: maxRetries,
      baseDelay: Duration.zero,
      timeout: timeout,
      isTransient: isTransient ?? (r) => r.statusCode == 503,
    );

void main() {
  group('postWithRetry', () {
    test('a good response comes back after a single request', () async {
      var calls = 0;
      final result = await _post(MockClient((_) async {
        calls++;
        return http.Response('ok', 200);
      }));

      expect(result.response.statusCode, 200);
      expect(result.attempts, 1);
      expect(calls, 1);
    });

    test('keeps retrying a transient response until it clears', () async {
      var calls = 0;
      final result = await _post(MockClient((_) async {
        calls++;
        return http.Response('', calls < 3 ? 503 : 200);
      }));

      expect(result.response.statusCode, 200);
      expect(result.attempts, 3);
    });

    test('gives up after maxRetries and returns the last response', () async {
      var calls = 0;
      final result = await _post(
        MockClient((_) async {
          calls++;
          return http.Response('', 503);
        }),
        maxRetries: 2,
      );

      expect(result.response.statusCode, 503);
      expect(result.attempts, 3); // the first try plus two retries
      expect(calls, 3);
    });

    test('maxRetries 0 means a single attempt', () async {
      var calls = 0;
      await _post(
        MockClient((_) async {
          calls++;
          return http.Response('', 503);
        }),
        maxRetries: 0,
      );

      expect(calls, 1);
    });

    test('does not retry a response that is not transient', () async {
      var calls = 0;
      final result = await _post(MockClient((_) async {
        calls++;
        return http.Response('', 401);
      }));

      expect(result.response.statusCode, 401);
      expect(calls, 1);
    });

    test('a request that does not answer in time fails fast, naming the '
        'provider', () async {
      await expectLater(
        _post(
          MockClient((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return http.Response('', 200);
          }),
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<LlmApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Prov'), contains('no respondió')),
        )),
      );
    });

    test('a hung request is not retried — that would multiply the wait',
        () async {
      var calls = 0;
      await expectLater(
        _post(
          MockClient((_) async {
            calls++;
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return http.Response('', 200);
          }),
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<LlmApiException>()),
      );
      expect(calls, 1);
    });

    test('a network failure becomes an LlmApiException naming the provider, '
        'without retrying', () async {
      var calls = 0;
      await expectLater(
        _post(MockClient((_) async {
          calls++;
          throw http.ClientException('connection refused');
        })),
        throwsA(isA<LlmApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Prov'), contains('connection refused')),
        )),
      );
      expect(calls, 1);
    });
  });
}
