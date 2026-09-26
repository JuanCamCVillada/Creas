import 'package:flutter/material.dart';

import '../../models/session.dart';
import '../theme/hud_alerts.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';
import 'arbol_genealogico_view.dart';
import 'canvas/graph_legend.dart';
import 'conectar_screen.dart';
import 'dashboard/hud_detail_panel.dart';
import 'dashboard/hud_stats_panel.dart';
import 'jardin_digital_view.dart';

/// The wide-layout breakpoint: below this, a single scrolling column with
/// modal node detail (phone/tablet); at or above it, the persistent
/// 3-column dashboard (desktop/web) that reuses the same graph views —
/// mobile-first, so the desktop layout is additive, not a rewrite.
const _wideBreakpoint = 900.0;

class GraphViewScreen extends StatelessWidget {
  const GraphViewScreen({super.key, required this.session});

  final GraphSession session;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth >= _wideBreakpoint
                ? _DesktopDashboard(session: session)
                : _MobileTabs(session: session);
          },
        ),
      ),
    );
  }
}

String _shortDate(DateTime dt) {
  const months = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];
  final local = dt.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}

Widget _connectarButton(BuildContext context, HudColors c, GraphSession session) {
  return InkWell(
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ConectarScreen(graph: session.graph),
    )),
    child: HudChamferedBox(
      fill: Colors.transparent,
      borderColor: c.contrast,
      borderWidth: 1.5,
      chamfer: 6,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text('CONECTAR', style: HudText.operativa(c.contrast, size: 12)),
    ),
  );
}

Widget _followupBanner(HudColors c, List<String> followupQuestions) {
  if (followupQuestions.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.all(12),
    child: HudHazardBanner(
      status: HudStatus.precaucion,
      glyph: '注意',
      title: 'DATOS INSUFICIENTES',
      subtitle: followupQuestions.join(' '),
    ),
  );
}

/// Narrow (phone/tablet) layout: the original tabbed, single-column
/// experience with modal node detail — untouched by the dashboard work so
/// mobile stays exactly as tested.
class _MobileTabs extends StatelessWidget {
  const _MobileTabs({required this.session});

  final GraphSession session;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final followupQuestions = session.graph.followupQuestions;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: HudIdBadge(label: 'Sesión · ${_shortDate(session.createdAt)}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: _connectarButton(context, c, session)),
            ),
          ],
          bottom: TabBar(
            indicatorColor: c.sys,
            labelColor: c.sys,
            unselectedLabelColor: c.textDim,
            labelStyle: HudText.operativa(c.sys, size: 13),
            unselectedLabelStyle: HudText.operativa(c.textDim, size: 13),
            tabs: const [
              Tab(text: '01 JARDÍN'),
              Tab(text: '02 LINAJE'),
            ],
          ),
        ),
        body: Column(
          children: [
            _followupBanner(c, followupQuestions),
            Expanded(
              child: TabBarView(
                children: [
                  JardinDigitalView(graph: session.graph),
                  ArbolGenealogicoView(graph: session.graph),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide (desktop/web) layout: the persistent 3-column HUD dashboard — a
/// left stats column, the center graph with a full-width legend bar, and
/// a right column that shows the last selected node's detail inline
/// instead of as a modal.
class _DesktopDashboard extends StatefulWidget {
  const _DesktopDashboard({required this.session});

  final GraphSession session;

  @override
  State<_DesktopDashboard> createState() => _DesktopDashboardState();
}

class _DesktopDashboardState extends State<_DesktopDashboard> {
  int _tabIndex = 0;
  Widget? _detail;

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
      _detail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final session = widget.session;
    final graph = session.graph;

    return Column(
      children: [
        Container(
          color: c.panel,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              HudIdBadge(label: 'Sesión · ${_shortDate(session.createdAt)}'),
              const SizedBox(width: 20),
              HudSegmentedTabs(
                labels: const ['01 JARDÍN', '02 LINAJE'],
                selectedIndex: _tabIndex,
                onSelected: _selectTab,
              ),
              const Spacer(),
              _connectarButton(context, c, session),
            ],
          ),
        ),
        _followupBanner(c, graph.followupQuestions),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HudStatsPanel(session: session),
              VerticalDivider(width: 1, color: c.grid),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _tabIndex == 0
                          ? JardinDigitalView(
                              graph: graph,
                              onNodeSelected: (w) => setState(() => _detail = w),
                              showLegend: false,
                            )
                          : ArbolGenealogicoView(
                              graph: graph,
                              onNodeSelected: (w) => setState(() => _detail = w),
                              showLegend: false,
                            ),
                    ),
                    GraphLegend(
                      fullWidth: true,
                      shapes: _tabIndex == 0
                          ? JardinDigitalView.legendShapes(c)
                          : ArbolGenealogicoView.legendShapes(c),
                      lines: _tabIndex == 0
                          ? JardinDigitalView.legendLines(c)
                          : ArbolGenealogicoView.legendLines(c, showAffinity: false),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: c.grid),
              HudDetailPanel(detail: _detail),
            ],
          ),
        ),
      ],
    );
  }
}
