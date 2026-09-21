import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:creative/engine/anthropic_client.dart';
import 'package:creative/engine/graph_generation_client.dart';

void main() {
  group('AnthropicClient', () {
    test('returns the tool_use input map on a successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        expect(request.headers['x-api-key'], 'test-key');
        expect(request.headers['anthropic-version'], isNotEmpty);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'claude-sonnet-5');
        expect(body['tool_choice'], {'type': 'tool', 'name': 'emit_creative_graph'});

        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'tool_use',
                'id': 'toolu_1',
                'name': 'emit_creative_graph',
                'input': {'nodes': [], 'edges': []},
              },
            ],
          }),
          200,
        );
      });

      final client = AnthropicClient(httpClient: mockClient);
      final result = await client.requestToolCall(
        apiKey: 'test-key',
        systemPrompt: 'system',
        userInput: 'input',
      );

      expect(result, {'nodes': [], 'edges': []});
    });

    test('throws AnthropicApiException on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "unauthorized"}', 401);
      });

      final client = AnthropicClient(httpClient: mockClient);

      expect(
        () => client.requestToolCall(
          apiKey: 'bad-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<AnthropicApiException>()),
      );
    });

    test('throws AnthropicApiException when no tool_use block is returned', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'no debería responder así'},
            ],
          }),
          200,
        );
      });

      final client = AnthropicClient(httpClient: mockClient);

      expect(
        () => client.requestToolCall(
          apiKey: 'test-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<AnthropicApiException>()),
      );
    });
  });
}
