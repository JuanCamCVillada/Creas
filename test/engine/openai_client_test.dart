import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/engine/openai_client.dart';

http.Response _models(List<String> ids) => http.Response(
      jsonEncode({
        'data': [for (final id in ids) {'id': id}],
      }),
      200,
    );

http.Response _toolCall(Map<String, dynamic> args) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {
              'tool_calls': [
                {
                  'type': 'function',
                  'function': {
                    'name': 'emit_creative_graph',
                    'arguments': jsonEncode(args),
                  },
                },
              ],
            },
          },
        ],
      }),
      200,
    );

OpenAiClient _client(MockClientHandler handler, {int maxRetries = 3}) => OpenAiClient(
      httpClient: MockClient(handler),
      maxRetries: maxRetries,
      baseRetryDelay: Duration.zero,
    );

Future<Map<String, dynamic>> _call(OpenAiClient client) => client.requestToolCall(
      apiKey: 'sk-test',
      systemPrompt: 'system',
      userInput: 'input',
    );

void main() {
  group('OpenAiClient', () {
    test('forces the emit_creative_graph function and returns its parsed arguments',
        () async {
      late Map<String, dynamic> sentBody;
      late http.Request sentRequest;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        sentRequest = request;
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _toolCall({'nodes': [], 'edges': []});
      });

      final result = await _call(client);

      expect(result, {'nodes': [], 'edges': []});
      expect(sentRequest.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(sentRequest.headers['authorization'], 'Bearer sk-test');
      expect(sentBody['tool_choice'], {
        'type': 'function',
        'function': {'name': 'emit_creative_graph'},
      });
      final messages = sentBody['messages'] as List<dynamic>;
      expect(messages.first, {'role': 'system', 'content': 'system'});
      expect(messages.last, {'role': 'user', 'content': 'input'});
    });

    test('sends the schema in standard JSON Schema, not Gemini\'s dialect',
        () async {
      late Map<String, dynamic> sentBody;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _toolCall({});
      });

      await _call(client);

      final parameters = ((sentBody['tools'] as List).first as Map)['function']['parameters']
          as Map<String, dynamic>;
      expect(parameters['type'], 'object');
      final nodeProps = ((parameters['properties'] as Map)['nodes'] as Map)['items']['properties']
          as Map<String, dynamic>;
      expect((nodeProps['type'] as Map)['type'], 'string');
      expect((nodeProps['type'] as Map).containsKey('format'), isFalse);
    });

    test('picks the cheapest capable model the account actually has', () async {
      String? modelUsed;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) {
          // No gpt-4.1-mini, so the next preference should win.
          return _models(['whisper-1', 'gpt-4o', 'gpt-4o-mini']);
        }
        modelUsed = (jsonDecode(request.body) as Map<String, dynamic>)['model'] as String;
        return _toolCall({});
      });

      await _call(client);

      expect(modelUsed, 'gpt-4o-mini');
    });

    test('never picks a reasoning model even when it is available — its '
        'hidden thinking tokens are billed as output for no gain here',
        () async {
      String? modelUsed;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) {
          return _models(['gpt-5-mini', 'gpt-5', 'o4-mini', 'gpt-4o']);
        }
        modelUsed = (jsonDecode(request.body) as Map<String, dynamic>)['model'] as String;
        return _toolCall({});
      });

      await _call(client);

      expect(modelUsed, 'gpt-4o');
    });

    test('caps how much a single generation may write', () async {
      late Map<String, dynamic> sentBody;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _toolCall({});
      });

      await _call(client);

      expect(sentBody['max_completion_tokens'], kMaxOutputTokens);
    });

    test('reports token usage, including cached and reasoning tokens, when '
        'asked to', () async {
      final lines = <String>[];
      final client = OpenAiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
          final body = jsonDecode(_toolCall({}).body) as Map<String, dynamic>;
          body['usage'] = {
            'prompt_tokens': 1900,
            'completion_tokens': 1450,
            'prompt_tokens_details': {'cached_tokens': 1024},
            'completion_tokens_details': {'reasoning_tokens': 0},
          };
          return http.Response(jsonEncode(body), 200);
        }),
        baseRetryDelay: Duration.zero,
        onUsage: lines.add,
      );

      await _call(client);

      expect(lines, hasLength(1));
      expect(lines.single, allOf(contains('1900'), contains('1450'), contains('1024')));
    });

    test('stays silent about usage when no logger is given', () async {
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        return _toolCall({});
      });

      await expectLater(_call(client), completes);
    });

    test('asks for the model list only once per key', () async {
      var listings = 0;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) {
          listings++;
          return _models(['gpt-4o-mini']);
        }
        return _toolCall({});
      });

      await _call(client);
      await _call(client);

      expect(listings, 1);
    });

    test('falls back to a default model when listing fails, so the real error '
        'surfaces from the actual request', () async {
      String? modelUsed;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) throw http.ClientException('offline');
        modelUsed = (jsonDecode(request.body) as Map<String, dynamic>)['model'] as String;
        return _toolCall({});
      });

      await _call(client);

      expect(modelUsed, 'gpt-4o-mini');
    });

    test('a pinned model skips the listing entirely', () async {
      var listings = 0;
      String? modelUsed;
      final client = OpenAiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/models')) listings++;
          modelUsed = (jsonDecode(request.body) as Map<String, dynamic>)['model'] as String;
          return _toolCall({});
        }),
        model: 'my-fine-tune',
        baseRetryDelay: Duration.zero,
      );

      await _call(client);

      expect(listings, 0);
      expect(modelUsed, 'my-fine-tune');
    });

    test('retries a 503 and succeeds once OpenAI recovers', () async {
      var completions = 0;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        completions++;
        return completions < 3 ? http.Response('{}', 503) : _toolCall({'ok': true});
      });

      final result = await _call(client);

      expect(result, {'ok': true});
      expect(completions, 3);
    });

    test('retries a plain rate-limit 429', () async {
      var completions = 0;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        completions++;
        return completions < 2
            ? http.Response('{"error":{"code":"rate_limit_exceeded"}}', 429)
            : _toolCall({});
      });

      await _call(client);

      expect(completions, 2);
    });

    test('does NOT retry an exhausted quota 429 — waiting cannot fix it, and '
        'says so plainly', () async {
      var completions = 0;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        completions++;
        return http.Response('{"error":{"code":"insufficient_quota"}}', 429);
      });

      await expectLater(
        _call(client),
        throwsA(isA<LlmApiException>().having(
          (e) => e.message,
          'message',
          contains('insufficient_quota'),
        )),
      );
      expect(completions, 1);
    });

    test('gives a clear overload message after exhausting retries', () async {
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        return http.Response('{}', 503);
      }, maxRetries: 1);

      await expectLater(
        _call(client),
        throwsA(isA<LlmApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('OpenAI'), contains('sobrecargado'), contains('2 intentos')),
        )),
      );
    });

    test('a per-call retry limit beats the client default', () async {
      var completions = 0;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        completions++;
        return http.Response('{}', 503);
      }, maxRetries: 3);

      await expectLater(
        client.requestToolCall(
          apiKey: 'sk-test',
          systemPrompt: 'system',
          userInput: 'input',
          maxRetries: 0,
        ),
        throwsA(isA<LlmApiException>()),
      );
      expect(completions, 1);
    });

    test('a network failure becomes an LlmApiException naming OpenAI', () async {
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        throw http.ClientException('offline');
      });

      await expectLater(
        _call(client),
        throwsA(isA<LlmApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('OpenAI'), contains('offline')),
        )),
      );
    });

    test('does not retry a 401', () async {
      var completions = 0;
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return http.Response('{}', 401);
        completions++;
        return http.Response('{"error":{"message":"Incorrect API key"}}', 401);
      });

      await expectLater(_call(client), throwsA(isA<LlmApiException>()));
      expect(completions, 1);
    });

    test('throws when the model answers without calling the function', () async {
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': 'no function call here'}},
            ],
          }),
          200,
        );
      });

      await expectLater(_call(client), throwsA(isA<LlmApiException>()));
    });

    test('throws when the function arguments are not valid JSON', () async {
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'tool_calls': [
                    {
                      'function': {'name': 'emit_creative_graph', 'arguments': '{not json'},
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      await expectLater(_call(client), throwsA(isA<LlmApiException>()));
    });

    test('throws when there are no choices', () async {
      final client = _client((request) async {
        if (request.url.path.endsWith('/models')) return _models(['gpt-4o-mini']);
        return http.Response(jsonEncode({'choices': <dynamic>[]}), 200);
      });

      await expectLater(_call(client), throwsA(isA<LlmApiException>()));
    });
  });
}
