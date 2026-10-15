import 'package:flutter/material.dart';

import '../engine/generation_engine.dart';
import '../engine/llm_provider.dart';
import 'theme/hud_text.dart';
import 'theme/hud_tokens.dart';

/// Tells the user a fallback provider produced their graph, and why the
/// first choice didn't. Shown through the app-wide [ScaffoldMessenger] so it
/// survives the input screen closing right after generation succeeds — the
/// moment the notice is actually needed.
///
/// A precaución, not an error: the graph arrived, but the primary provider
/// is misbehaving and the user may want to know before it costs them.
void showFailoverNotice(
  GlobalKey<ScaffoldMessengerState> messengerKey,
  FailoverNotice notice,
) {
  final c = HudColors.consola;
  final failedNames = notice.failed.map((f) => f.provider.label).join(' Y ');
  final plural = notice.failed.length > 1;

  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
      // No drop shadow: hud-tactico has none, and on a chamfered shape it
      // shows as a black rectangle behind the cut corners.
      elevation: 0,
      backgroundColor: c.panel,
      shape: BeveledRectangleBorder(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        side: BorderSide(color: c.caution, width: 1.5),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('注意', style: HudText.operativa(c.caution, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$failedNames ${plural ? 'NO RESPONDIERON' : 'NO RESPONDIÓ'}'
                  ' · SE USÓ ${notice.used.label}',
                  style: HudText.operativa(c.text, size: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  notice.failed.first.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HudText.terminal(c.text2, size: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
}
