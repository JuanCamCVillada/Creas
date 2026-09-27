# Genealogía Creativa

Convierte un devlog, una retro o una transcripción en un grafo de conocimiento:
qué fuentes te inspiraron, qué conceptos derivaron de ellas y dónde estuvieron
los puntos de inflexión reales de tu proceso creativo.

La app le pasa tu texto a Gemini con una llamada a función forzada, verifica
que el grafo resultante sea acíclico y que los puntos de inflexión declarados
cumplan sus condiciones (convergencia de varias fuentes + cambio de dirección
real) antes de mostrarlo — nada se muestra como "verificado" sin serlo.

## Cómo se ve el grafo

Dos formas de explorarlo, más una que las fusiona:

- **🌱 Jardín Digital** — mapa exploratorio no dirigido. Los nodos conectados
  por una afinidad real se agrupan en columnas por cluster; los que no tienen
  ninguna conexión orbitan como planetas sueltos alrededor de esa masa
  conectada, en vez de dispersarse al azar.
- **🌳 Árbol Genealógico** — el linaje dirigido: fuente → concepto → punto de
  inflexión → síntesis, organizado en columnas de generación.
- **🔗 Conectar** — superpone las conexiones de afinidad de Jardín sobre el
  árbol de Linaje, sin duplicar lógica entre las dos vistas.

Ambas comparten el mismo lienzo panorámico/con zoom (nodos arrastrables,
conectores curvos con glow) y el mismo panel de detalle por nodo.

## Dos formas de escribir la entrada

- **GUIADO** — un asistente pregunta por pasos (problema, fuentes, primer
  intento, punto de inflexión, resolución) y obliga a responder cada uno
  antes de avanzar, para asegurar una descripción completa.
- **LIBRE** — el campo de texto de siempre, para pegar el devlog tal cual.

Ambos muestran el mismo aviso: *la calidad del resultado depende del prompt
ingresado y del problema descrito.*

## Diseño

Sistema propio **HUD Táctico**: estética de sala de control — paneles con
esquinas achaflanadas (nunca `border-radius`), tipografía condensada en
mayúsculas + monoespaciada para datos, glyphs en japonés como acento
decorativo, y tres modos de estado (NOMINAL / PRECAUCIÓN / EMERGENCIA) que
tiñen la interfaz según señales reales del grafo (una fuente con confianza
baja, datos insuficientes), nunca por decoración.

Layout responsive: en escritorio/web, un panel de 3 columnas persistente
(estadísticas reales del grafo + grafo + detalle de nodo); en móvil, la misma
información vive en modales.

## Arquitectura

```
lib/
├── engine/     # Cliente de Gemini, prompt del sistema, parseo y verificación del grafo
├── models/     # Node, LineageEdge, AffinityEdge, TurningPoint, CreativeGraph, GraphSession
├── storage/    # Clave de API (flutter_secure_storage) y sesiones (SharedPreferences)
└── ui/
    ├── input/      # Pantalla de entrada — modos GUIADO y LIBRE
    ├── graph/      # Jardín Digital, Árbol Genealógico, Conectar, lienzo compartido
    ├── sessions/   # Lista de sesiones guardadas
    ├── settings/   # Credencial de Gemini
    └── theme/      # Tokens de color, tipografía y widgets del sistema HUD Táctico
```

## Empezar

```bash
flutter pub get
flutter run -d chrome   # o -d web-server para desarrollo con hot reload manual
```

La app pide tu propia clave de API de Gemini la primera vez (ícono de llave,
arriba a la derecha) — se guarda cifrada en el dispositivo, nunca en el
repositorio.

## Tests

```bash
flutter test
```

30 archivos de test cubriendo el motor de generación, el layout de ambos
grafos (incluyendo casos límite: grafos vacíos, un solo nodo, clusters muy
desbalanceados), y cada pantalla en varios tamaños de viewport.
