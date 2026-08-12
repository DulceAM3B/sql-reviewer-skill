# sql-reviewer
## ¿Qué es esto?

`sql-reviewer` no es un prompt. Es un procedimiento especificado con reglas
deterministas (`IF ... THEN severity = ...`), niveles de severidad fijos,
manejo explícito de casos ambiguos, y un conjunto de pruebas que demuestran
su comportamiento — incluyendo casos donde la primera versión de una regla
falló y tuvo que corregirse (ver `tests/test-05.md`).

## Estructura

```
sql-reviewer-skill/
├── SKILL.md              # Especificación completa: propósito, activación,
│                          # procedimiento, reglas, severidades, output,
│                          # validación y manejo de fallos.
├── README.md              # Este archivo.
├── rules/
│   ├── security.md        # Reglas SEC-01 a SEC-08 (inyección, DELETE/UPDATE
│   │                       # sin WHERE efectivo, permisos, secretos).
│   ├── performance.md     # Reglas PERF-01 a PERF-08 (SELECT *, LIMIT,
│   │                       # índices, sargability, tipos de datos).
│   └── conventions.md     # Reglas CONV-01 a CONV-09 (nombres, NULL,
│                           # transacciones sin cierre).
├── examples/
│   ├── valid.sql           # SQL correcto: no debe generar hallazgos falsos.
│   ├── invalid.sql         # SQL con violaciones evidentes y múltiples.
│   └── edge-cases.sql      # SQL que pasa reglas superficiales pero es
│                            # peligroso (WHERE 1=1, LIMIT absurdo, etc.).
└── tests/
    ├── test-01.md           # Happy path
    ├── test-02.md           # Error evidente
    ├── test-03.md           # Edge case
    ├── test-04.md           # Información insuficiente
    └── test-05.md           # Adversarial — incluye un fallo real corregido
```

## Cómo usar la skill

1. Proveer el SQL a revisar como `sql_text` (ver "Inputs" en `SKILL.md`).
2. Opcionalmente, proveer `dialect`, `schema_context` y `execution_context`
   para hallazgos más precisos (índices, tipos de datos). Sin ellos, la
   skill degrada esos hallazgos a advertencias condicionales — nunca los
   omite ni los inventa.
3. La skill sigue el procedimiento fijo de 6 pasos descrito en `SKILL.md`
   y entrega un reporte por sentencia, con severidad, regla que originó
   cada hallazgo, y recomendación.

## Decisiones técnicas clave

- **Determinismo vs. razonamiento**: las reglas en `rules/` son fijas y
  reproducibles. La evaluación de intención semántica (¿este WHERE filtra
  algo de verdad?) es la única parte que depende del razonamiento del
  modelo, y está aislada y documentada como tal en el paso 5 del
  procedimiento — precisamente porque es la parte que un ataque adversarial
  puede intentar explotar.
- **No inventar contexto**: ante falta de `schema_context` o ambigüedad de
  intención, la skill reporta incertidumbre explícita en vez de asumir un
  escenario. Ver sección "Failure handling" en `SKILL.md` y `test-04.md`.
- **Reglas de evasión como reglas de primera clase**: SEC-02, SEC-05 y
  PERF-02b existen específicamente para cubrir los tres ejemplos de ataque
  del enunciado de la actividad, no como parche posterior sino como parte
  formal del set de reglas.

## Cómo correr las pruebas

Las pruebas en `tests/` son manuales/documentales (no hay un runner
automatizado): cada archivo documenta el input, el comportamiento esperado
y el comportamiento real observado al pasarle ese input a la skill. Para
añadir una prueba nueva, copiar el formato de cualquier `test-XX.md`.

## Historial de Red Team

Documentado en `test-05.md`: la regla SEC-01 original (solo verificaba
presencia sintáctica de `WHERE`) fue evadida con `DELETE ... WHERE 1=1`
durante la fase de Red Team. Corregida con la adición de SEC-02.
