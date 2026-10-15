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

    test('throws LlmApiException on a non-200 response', () async {
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
        throwsA(isA<LlmApiException>()),
      );
    });

    test('throws LlmApiException when no functionCall part is returned',
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
        throwsA(isA<LlmApiException>()),
      );
    });

    test('caps how much a single generation may write', () async {
      late Map<String, dynamic> sentBody;
      final mockClient = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {'name': 'emit_creative_graph', 'args': {}},
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      await GeminiClient(httpClient: mockClient).requestToolCall(
        apiKey: 'test-key',
        systemPrompt: 'system',
        userInput: 'input',
      );

      expect(
        (sentBody['generationConfig'] as Map)['maxOutputTokens'],
        kMaxOutputTokens,
      );
    });

    test('reports token usage, including thinking tokens, when asked to',
        () async {
      final lines = <String>[];
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {'name': 'emit_creative_graph', 'args': {}},
                    },
                  ],
                },
              },
            ],
            'usageMetadata': {
              'promptTokenCount': 2100,
              'candidatesTokenCount': 1380,
              'thoughtsTokenCount': 640,
            },
          }),
          200,
        );
      });

      await GeminiClient(httpClient: mockClient, onUsage: lines.add).requestToolCall(
        apiKey: 'test-key',
        systemPrompt: 'system',
        userInput: 'input',
      );

      expect(lines, hasLength(1));
      expect(lines.single, allOf(contains('2100'), contains('1380'), contains('640')));
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
        throwsA(isA<LlmApiException>().having(
          (e) => e.toString(),
          'message',
          contains('sobrecargado'),
        )),
      );
      // The original attempt plus maxRetries retries.
      expect(callCount, 3);
    });

    test('a per-call retry limit beats the client default', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('{"error": {"code": 503}}', 503);
      });
      final client = GeminiClient(
        httpClient: mockClient,
        maxRetries: 3,
        baseRetryDelay: Duration.zero,
      );

      await expectLater(
        client.requestToolCall(
          apiKey: 'test-key',
          systemPrompt: 'system',
          userInput: 'input',
          maxRetries: 0,
        ),
        throwsA(isA<LlmApiException>()),
      );
      expect(callCount, 1);
    });

    test('a network failure becomes an LlmApiException naming Gemini', () async {
      final client = GeminiClient(
        httpClient: MockClient((_) async => throw http.ClientException('offline')),
        baseRetryDelay: Duration.zero,
      );

      await expectLater(
        client.requestToolCall(apiKey: 'k', systemPrompt: 's', userInput: 'i'),
        throwsA(isA<LlmApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Gemini'), contains('offline')),
        )),
      );
    });

    test('a request that never answers fails instead of hanging, so a '
        'fallback can take over', () async {
      final client = GeminiClient(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response('{}', 200);
        }),
        requestTimeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        client.requestToolCall(apiKey: 'k', systemPrompt: 's', userInput: 'i'),
        throwsA(isA<LlmApiException>().having(
          (e) => e.message,
          'message',
          contains('no respondió'),
        )),
      );
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
        throwsA(isA<LlmApiException>()),
      );
      expect(callCount, 1);
    });

    test('throws LlmApiException when there are no candidates', () async {
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
        throwsA(isA<LlmApiException>()),
      );
    });
  });
}
