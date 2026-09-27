import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:creative/engine/gemini_client.dart';
import 'package:creative/engine/graph_generation_client.dart';

void main() {
  group('GeminiClient', () {
    test('returns the functionCall args on a successful response', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent',
        );
        expect(request.headers['x-goog-api-key'], 'test-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final toolConfig = body['toolConfig'] as Map<String, dynamic>;
        final functionCallingConfig =
            toolConfig['functionCallingConfig'] as Map<String, dynamic>;
        expect(functionCallingConfig['mode'], 'ANY');
        expect(functionCallingConfig['allowedFunctionNames'],
            ['emit_creative_graph']);

        final contents = body['contents'] as List<dynamic>;
        expect(contents.single['parts'], [
          {'text': 'input'}
        ]);

        final systemInstruction =
            body['systemInstruction'] as Map<String, dynamic>;
        expect(systemInstruction['parts'], [
          {'text': 'system'}
        ]);

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'emit_creative_graph',
                        'args': {'nodes': [], 'edges': []},
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final client = GeminiClient(httpClient: mockClient);
      final result = await client.requestToolCall(
        apiKey: 'test-key',
        systemPrompt: 'system',
        userInput: 'input',
      );

      expect(result, {'nodes': [], 'edges': []});
    });

    test('throws GeminiApiException on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "unauthorized"}', 401);
      });

      final client = GeminiClient(httpClient: mockClient);

      expect(
        () => client.requestToolCall(
          apiKey: 'bad-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<GeminiApiException>()),
      );
    });

    test('throws GeminiApiException when no functionCall part is returned',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'no debería responder así'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final client = GeminiClient(httpClient: mockClient);

      expect(
        () => client.requestToolCall(
          apiKey: 'test-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<GeminiApiException>()),
      );
    });

    test('retries on a 503 and succeeds once the model responds', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          return http.Response(
              '{"error": {"code": 503, "status": "UNAVAILABLE"}}', 503);
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'emit_creative_graph',
                        'args': {'nodes': [], 'edges': []},
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final client = GeminiClient(
        httpClient: mockClient,
        baseRetryDelay: Duration.zero,
      );
      final result = await client.requestToolCall(
        apiKey: 'test-key',
        systemPrompt: 'system',
        userInput: 'input',
      );

      expect(result, {'nodes': [], 'edges': []});
      expect(callCount, 3);
    });

    test('gives a clear overload message after exhausting retries on a '
        'persistent 503', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
            '{"error": {"code": 503, "status": "UNAVAILABLE"}}', 503);
      });

      final client = GeminiClient(
        httpClient: mockClient,
        maxRetries: 2,
        baseRetryDelay: Duration.zero,
      );

      await expectLater(
        () => client.requestToolCall(
          apiKey: 'test-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<GeminiApiException>().having(
          (e) => e.toString(),
          'message',
          contains('sobrecargado'),
        )),
      );
      // The original attempt plus maxRetries retries.
      expect(callCount, 3);
    });

    test('does not retry a non-transient error like 401', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('{"error": "unauthorized"}', 401);
      });

      final client = GeminiClient(httpClient: mockClient, baseRetryDelay: Duration.zero);

      await expectLater(
        () => client.requestToolCall(
          apiKey: 'bad-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<GeminiApiException>()),
      );
      expect(callCount, 1);
    });

    test('throws GeminiApiException when there are no candidates', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'candidates': <dynamic>[]}), 200);
      });

      final client = GeminiClient(httpClient: mockClient);

      expect(
        () => client.requestToolCall(
          apiKey: 'test-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<GeminiApiException>()),
      );
    });
  });
}
