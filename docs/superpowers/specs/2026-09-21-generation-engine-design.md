# Generation Engine — Design Spec

Date: 2026-09-21
App: Genealogía Creativa (Flutter, `creative/`)

## Purpose

Turn a single free-form input (devlog, retro, brain dump, already-transcribed
voice note) into one shared creative-provenance graph, then render it as two
views: **Jardín Digital** (clustered, undirected, exploratory map of raw
material) and **Árbol Genealógico de Inspiración** (directed lineage of how
the idea evolved and who/what shaped it). Both views must be trustworthy: no
fabricated memories presented as the user's own, and turning points must be
ones the user recognizes as real.

## Scope

- Generation engine: input capture → LLM call → parsed/validated graph →
  local persistence.
- Both view renderers, built on the same graph.
- Text input only (no in-app audio recording/transcription).
- User supplies their own Gemini API key (free tier); app calls the Gemini
  `generateContent` API directly (no backend proxy) for this iteration.
- Target platforms: web, iOS, Android (avoid platform-specific code/plugins
  without web support).

## Architecture

Five layers, each independently testable:

1. **Input** — a screen with a multiline text field and a "Generar" action.
2. **Generation engine** — builds the system prompt + a forced function call
   to `emit_creative_graph`, calls the Gemini API with the user's key, and
   parses the returned function-call arguments into Dart models.
3. **Verification layer** — pure Dart, no LLM: checks the lineage is
   acyclic, and structurally validates each turning-point *candidate* the
   model proposed against the edges actually emitted. Candidates that fail
   are dropped before the graph reaches the UI.
4. **Local store** — each generated graph (raw input, parsed graph, verified
   turning points) persisted as a JSON blob, so past sessions are browsable.
5. **View renderers** — Jardín Digital (force-directed, undirected) and
   Árbol Genealógico (layered/tree, directed), both consuming the same graph
   object, laid out via the `graphview` package.

```
[Input screen] -> [Generation engine: prompt + Gemini API]
                        -> [Parse tool-call args into Dart models]
                        -> [Verification layer: cycle check, turning-point check]
                        -> [Local store (shared_preferences, JSON per session)]
                        -> [Jardín Digital view] / [Árbol Genealógico view]
```

## Data model

### Node

```
{
  id: String,
  type: "fuente" | "concepto",
  label: String,
  description: String,
  cluster: String,              // kebab-case domain tag
  origin: "usuario" | "sugerido",
  confidence: double?,          // required when origin == "sugerido"
  timestamp: String?,           // ISO date, only if input gives/implies it
  sequence: int?,               // relative order when timestamp is null
  level: 1 | 2 | null,          // referente pedigree, fuente-only (see below)
  referenteOf: String?,         // id of the level-below fuente this was suggested from
}
```

Level 0 ("TÚ", the user) is a synthetic root node the app always adds; the
LLM never emits it. It is not part of `nodes` in the tool schema — the app
inserts it when building the Árbol view.

### Edge (directed lineage)

```
{
  id: String,
  source: String,   // node id
  target: String,   // node id
  relation: "desencadena" | "deriva_de" | "inspira" | "transforma_en",
}
```

Constraint enforced at parse time: `source` must be a Fuente or Concepto,
`target` must be a Concepto (S→C or C→C only — a Fuente edge targeting
another Fuente is rejected as a schema violation). The lineage graph over
these edges must be acyclic (verification layer checks this explicitly).

### Referente pedigree (Level 1/2), not a lineage edge

The "who inspired their inspirations" relationship (TÚ → direct referentes →
their referentes) is modeled as node attributes (`level`, `referenteOf`), not
as an edge in the `edges` list. This keeps "Fuentes only point into
Conceptos, never into each other" true for the concept-evolution graph, while
still letting the Árbol view draw TÚ → L1 → L2 as a tree branch. The app
builds the TÚ→L1 and L1→L2 tree edges for rendering purposes only, from these
attributes — they are display edges, not part of the verified lineage.

### Affinity edge (Jardín Digital, undirected)

```
{
  source: String,
  target: String,
  weight: double,   // 0..1, affinity_weight
}
```

### Turning-point candidate (as proposed by the LLM)

```
{
  nodeId: String,
  evidence: String,   // what collided, what changed afterward, in the user's words
}
```

### Turning point (post-verification)

Same shape, plus the two structurally-checked booleans, only surfaced to the
UI when both are true:

- `convergence`: the candidate node has ≥2 incoming Fuente edges whose source
  nodes have ≥2 distinct `cluster` values.
- `directionChange`: the set of clusters reachable via the candidate's
  outgoing C→C edges is not a subset of the set of clusters feeding into it
  (incoming Fuente clusters ∪ the clusters of any incoming Concepto sources
  ∪ the candidate's own cluster — "before it" includes the point itself,
  so a child in the same cluster as the candidate is not a direction
  change). I.e., at least one downstream cluster is new relative to
  upstream-plus-the-candidate-itself.

A candidate that fails either check is dropped silently — this is expected
behavior per the product spec ("an honest graph without turning points is
better than an invented epiphany"), not an error state.

### Tool schema (`emit_creative_graph`)

```
{
  nodes: Node[],
  edges: Edge[],
  affinity_edges: AffinityEdge[],
  turning_point_candidates: TurningPointCandidate[],
  followup_questions: string[],
}
```

## Generation engine flow

1. Build the system prompt from the product spec (node/edge model, turning
   point rules, grounding rules, the two views) — the spec as given is
   already precise enough to serve as the system prompt near-verbatim.
2. Call `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent` with:
   - `contents: [{role: "user", parts: [{text: userInput}]}]`
   - `systemInstruction: {parts: [{text: systemPrompt}]}`
   - `tools: [{functionDeclarations: [emit_creative_graph schema]}]`
   - `toolConfig: {functionCallingConfig: {mode: "ANY", allowedFunctionNames: ["emit_creative_graph"]}}`
   - the user's API key in the `x-goog-api-key` header, read from secure storage
3. Parse the tool-call arguments into the Dart models above. On a
   schema-mismatched or malformed response, retry the call once; on a
   second failure, surface a clear error ("no se pudo generar el grafo") —
   never guess or partially render.
4. Run the verification layer (acyclicity, turning-point structural checks).
   If a cycle is found in the lineage edges, reject the whole response and
   show "el modelo produjo una línea de tiempo inconsistente" with a
   regenerate action — never silently drop edges to force acyclicity.
5. Persist the session and hand the verified graph to the views.

## Persistence

Each session (raw input, parsed graph, verified turning points, timestamp)
is serialized to JSON and stored as an entry in a list under one
`shared_preferences` key. No native DB dependency — works identically on
web (localStorage-backed), iOS, and Android. A simple list screen shows past
sessions by input snippet + date; tapping reopens both views for that
session. No search/filter in this iteration.

The user's Gemini API key is stored via `flutter_secure_storage` (OS
keychain on iOS/Android; browser-storage-backed encryption on web — noted to
the user as best-effort on web, not OS-grade).

## Views

Both built on `graphview`, consuming the same verified graph:

- **Jardín Digital**: `FruchtermanReingold` (force-directed) layout over all
  nodes and `affinity_edges`, undirected. A light pre-pass nudges same-
  `cluster` nodes into initial proximity before the algorithm relaxes. Loose
  fragments (nodes with no lineage edges) are included, not filtered out.
- **Árbol Genealógico**: `Sugiyama` (layered) layout, top-down. Level 0 (TÚ,
  synthetic) at the top, Level 1/2 referentes below via the display edges
  built from `level`/`referenteOf`, and the concept lineage (`edges`)
  hanging off whichever Fuentes fed it.
- Tapping any node opens a detail sheet: label, description, origin,
  confidence (if sugerido), cluster.
- `origin: "sugerido"` nodes render with a distinct style (dashed border)
  and carry accept/reject actions that mutate local view state only — no
  regeneration call.
- Turning-point nodes get a badge; tapping shows the `evidence` text.
- If `followup_questions` is non-empty (thin input), render them as prompts
  above the Jardín view instead of an empty/sparse Árbol.

## Error handling

- Network/API failure → dismissible error banner with retry.
- Malformed tool-call response → one silent retry, then explicit error.
- Cycle in lineage edges → reject response, show error + regenerate action.
- Turning-point candidate fails structural checks → dropped silently
  (expected, not an error).
- Missing/invalid API key → block generation with an inline prompt to enter
  one, rather than firing a request that will 401.

## Testing approach

- Unit tests for the verification layer (cycle detection, turning-point
  convergence/direction-change checks) against hand-built node/edge
  fixtures — this is the part with real logic and no UI dependency.
- Unit tests for tool-call response parsing (valid schema, missing fields,
  invalid S→S edge, cyclic edges) using recorded/fixture JSON, no live API
  calls in tests.
- Widget tests for the input screen and session list.
- Manual verification of both view renderers in the browser (web target)
  against a real generated graph, since layout/rendering correctness isn't
  meaningfully unit-testable.

## Out of scope for this iteration

- In-app audio recording/transcription.
- Backend proxy / server-held API keys.
- Editing the graph beyond accept/reject of sugerido nodes.
- Search/filter over session history.
- Non-Spanish localization of the system prompt (labels/descriptions already
  preserve the user's own language per the grounding rules).
