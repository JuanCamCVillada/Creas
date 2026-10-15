# Genealogía Creativa

Convierte un devlog, una retro o una transcripción en un grafo de conocimiento:
qué fuentes te inspiraron, qué conceptos derivaron de ellas y dónde estuvieron
los puntos de inflexión reales de tu proceso creativo.

La app le pasa tu texto a Gemini u OpenAI, verifica que el grafo resultante sea
acíclico y que los puntos de inflexión declarados cumplan sus condiciones
(convergencia de varias fuentes + cambio de dirección real) antes de
mostrarlo — nada se muestra como "verificado" sin serlo.

## Cómo se ve el grafo

Dos formas de explorarlo, más una que las fusiona:

- **🌱 Jardín Digital** — mapa exploratorio no dirigido. Los nodos conectados
  por una afinidad real se agrupan en columnas por cluster; los que no tienen
  ninguna conexión orbitan como planetas sueltos alrededor de esa masa
  conectada, en vez de dispersarse al azar.
- **🌳 Árbol Genealógico** — el linaje dirigido: fuente → concepto → punto de
  inflexión → síntesis, organizado en columnas de generación.
- **🔗 Conectar** — superpone las conexiones de afinidad de Jardín sobre el
  árbol de Linaje.

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
├── engine/     # Clientes de Gemini y OpenAI, detección de proveedor, prompt del sistema, parseo y verificación del grafo
├── models/     # Node, LineageEdge, AffinityEdge, TurningPoint, CreativeGraph, GraphSession
├── storage/    # Clave de API (flutter_secure_storage) y sesiones (SharedPreferences)
└── ui/
    ├── input/      # Pantalla de entrada — modos GUIADO y LIBRE
    ├── graph/      # Jardín Digital, Árbol Genealógico, Conectar, lienzo compartido
    ├── sessions/   # Lista de sesiones guardadas
    ├── settings/   # Clave de API: validación y elección de proveedor
    └── theme/      # Tokens de color, tipografía y widgets del sistema HUD Táctico
```

La app pide tu propia clave de API la primera vez (ícono de llave, arriba a la
derecha): pega una clave de **Gemini** (`AIza…`) o de **OpenAI** (`sk-…`) y el
proveedor se detecta solo por el formato; si no lo reconoce, lo eliges a mano.
Antes de guardarla se verifica contra la API del proveedor. Se guarda cifrada en
el dispositivo, nunca en el repositorio.

Puedes guardar **una clave por proveedor**. Con dos, uno es el principal y el
otro queda de respaldo: si el principal está sobrecargado, sin cuota, caído o
devuelve un grafo inservible, la misma petición pasa sola al siguiente, y la app
te avisa cuál falló y cuál generó el grafo.
