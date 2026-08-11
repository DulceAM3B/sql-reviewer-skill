# SQL Reviewer

## Purpose

`sql-reviewer` es una skill que actúa como revisor técnico de sentencias y
scripts SQL antes de que lleguen a un entorno de ejecución (desarrollo, QA o
producción). Su responsabilidad es **detectar y clasificar** riesgos de
seguridad, rendimiento y convenciones en SQL, y **explicar por qué** cada
hallazgo es un problema — nunca ejecutar, corregir automáticamente, ni asumir
intención sobre datos que no están en el input.

La skill no reemplaza a un DBA ni a un pipeline de CI de SQL linting. Es una
capa de revisión adicional, determinista en sus reglas y explícita en sus
límites.

## When to activate

Activar `sql-reviewer` cuando el input sea:

- Una o más sentencias SQL (SELECT, INSERT, UPDATE, DELETE, DDL) enviadas
  como texto o archivo `.sql`.
- Un script SQL completo (múltiples sentencias separadas por `;`).
- Un fragmento de código de aplicación que contiene SQL embebido explícito
  (ej. un string dentro de una función), siempre que el SQL sea identificable
  con claridad.
- Una solicitud explícita de "revisa este SQL", "audita esta query",
  "¿esta sentencia es segura/eficiente?".

## When NOT to activate

La skill **no debe activarse**, y debe decirlo explícitamente, cuando:

- El input no contiene SQL identificable (texto ambiguo, pseudocódigo sin
  sintaxis SQL reconocible).
- Se solicita **generar** SQL nuevo desde cero sin nada que revisar (eso es
  una tarea distinta: generación, no revisión).
- Se pide que la skill **ejecute** la sentencia contra una base de datos real
  o simulada. `sql-reviewer` analiza texto, no ejecuta nada.
- El SQL está incompleto de forma que impide determinar su comportamiento
  (ej. una sentencia cortada a la mitad, sin poder inferir el resto) — en
  este caso la skill reporta "información insuficiente" en lugar de analizar
  el fragmento como si estuviera completo.
- Se pide una opinión de diseño de arquitectura de base de datos (modelado
  ER, normalización completa de un esquema) — eso excede el alcance de
  revisión de sentencias puntuales.

## Inputs

| Campo | Obligatorio | Descripción |
|---|---|---|
| `sql_text` | Sí | Una o más sentencias SQL en texto plano. |
| `dialect` | No (default: `generic`) | Motor de base de datos: `mysql`, `postgres`, `sqlserver`, `oracle`, `generic`. Afecta reglas específicas de sintaxis (ver "Failure handling" sobre dialectos no soportados). |
| `schema_context` | No | Definiciones de tablas/columnas/índices conocidas, si están disponibles. Sin esto, ciertas reglas (ej. índices faltantes) se degradan a advertencias condicionales, ver Rule ENG-01. |
| `execution_context` | No | Dónde se ejecutará la sentencia: `production`, `staging`, `development`. Sin este dato, la skill asume el escenario de mayor riesgo (`production`) para efectos de severidad. |

Si `sql_text` está vacío o no contiene SQL parseable, la skill **no genera
un análisis**: responde indicando que no hay SQL que revisar.

## Procedure

La skill sigue un procedimiento fijo de 6 pasos. No se permite saltar pasos
ni reordenarlos.

1. **Parseo estructural**: identificar el tipo de sentencia (SELECT, INSERT,
   UPDATE, DELETE, DDL, otro) y separar el script en sentencias individuales.
   Si una sentencia no puede clasificarse, se marca como `UNPARSEABLE` y pasa
   directo a "Failure handling" — no se le aplican las reglas siguientes.
2. **Análisis de seguridad**: aplicar todas las reglas de `rules/security.md`
   a cada sentencia.
3. **Análisis de rendimiento**: aplicar todas las reglas de
   `rules/performance.md`.
4. **Análisis de convenciones**: aplicar todas las reglas de
   `rules/conventions.md`.
5. **Evaluación de intención y contexto** (razonamiento no determinista,
   ver "Deterministic vs reasoning-based" abajo): para hallazgos que pasan
   las reglas superficiales pero cuyo efecto real es sospechoso (ej.
   `WHERE 1=1`, `LIKE '%'` sin más filtros, `LIMIT` absurdamente alto), la
   skill debe razonar explícitamente sobre el impacto probable, no solo
   verificar la presencia sintáctica de la cláusula.
6. **Consolidación del reporte**: agrupar hallazgos por sentencia, asignar
   severidad según "Severity levels", y generar el output en el formato de
   "Expected output".

### Deterministic vs reasoning-based

Es importante distinguir qué partes de esta skill son reglas fijas y cuáles
dependen del razonamiento del modelo, porque se evalúa explícitamente en la
defensa:

- **Deterministas** (si-entonces fijo, no varían): todas las reglas
  numeradas en `rules/security.md`, `rules/performance.md` y
  `rules/conventions.md`. Dada la misma sentencia, siempre disparan el mismo
  hallazgo con la misma severidad base.
- **Basadas en razonamiento** (el modelo evalúa intención/impacto): el paso
  5 del procedimiento. Ejemplos: decidir si un `WHERE 1=1` en un `DELETE`
  es "técnicamente tiene WHERE" (pasa la regla sintáctica) pero
  semánticamente equivalente a no tener condición (debe escalar a
  CRITICAL igual). Esta capa existe precisamente porque las reglas
  sintácticas por sí solas son evadibles (ver fase Red Team).

## Rules

Las reglas completas y numeradas están en `rules/security.md`,
`rules/performance.md` y `rules/conventions.md`. Aquí se listan solo los
ejemplos formales de cómo se expresan (todas las reglas siguen esta
sintaxis):

```
RULE SEC-01: DELETE / UPDATE sin WHERE
IF statement.type IN (DELETE, UPDATE)
AND statement.WHERE is absent
THEN severity = CRITICAL
AND finding = "Sentencia destructiva sin condición WHERE"
AND recommendation = "No ejecutar. Agregar condición WHERE explícita."
AND block_execution_recommendation = true
```

```
RULE SEC-02: WHERE trivialmente verdadero (evasión semántica)
IF statement.type IN (DELETE, UPDATE)
AND statement.WHERE exists
AND WHERE evaluates to a condition that is always true for all rows
    (ej. "1=1", "col LIKE '%'", "col = col", "1<>0")
THEN severity = CRITICAL
AND finding = "WHERE presente pero semánticamente equivalente a ausencia de condición"
AND recommendation = "No ejecutar. La condición no filtra ninguna fila."
```

La lista completa (mínimo cubre: `SELECT *`, DELETE/UPDATE sin WHERE seguro,
operaciones destructivas, SQL Injection por concatenación, nombres poco
descriptivos, ausencia de LIMIT en consultas masivas, uso incorrecto de
NULL, tipos de datos deficientes, índices potencialmente faltantes,
problemas de rendimiento razonables, y las reglas adicionales del equipo)
está en los archivos de `rules/`.

## Severity levels

| Nivel | Significado | Ejemplos |
|---|---|---|
| **CRITICAL** | Riesgo de pérdida de datos irreversible, brecha de seguridad explotable, o caída de servicio en producción. | DELETE/UPDATE sin WHERE efectivo, SQL Injection por concatenación directa de input de usuario, DROP/TRUNCATE sin confirmación explícita. |
| **HIGH** | Riesgo serio pero no necesariamente irreversible de inmediato; requiere corrección antes de producción. | UPDATE que afecta un rango no acotado (`LIMIT` ausente en operación masiva combinado con filtro amplio), falta de índice en columna usada en WHERE de tabla grande. |
| **MEDIUM** | Problema real de calidad o rendimiento, pero con impacto acotado o mitigable. | `SELECT *` en tabla con muchas columnas, ausencia de LIMIT en SELECT exploratorio, tipo de dato subóptimo (ej. `VARCHAR(255)` para un email). |
| **LOW** | Problema de mantenibilidad o buenas prácticas, sin impacto funcional inmediato. | Nombres de tablas/columnas poco descriptivos, inconsistencia de convención de mayúsculas. |
| **INFO** | Observación o sugerencia, no un defecto. | Sugerencia de índice compuesto para un patrón de query frecuente, nota sobre alternativa de diseño. |

Regla de consolidación: si una misma sentencia dispara múltiples hallazgos,
la severidad reportada para la sentencia en el resumen es la del hallazgo
más alto (CRITICAL > HIGH > MEDIUM > LOW > INFO). Cada hallazgo individual
conserva su propia severidad en el detalle.

## Expected output

Para cada sentencia analizada, el output debe seguir esta estructura:

```
### Statement N: <tipo de sentencia, primeras palabras>

**Severidad global:** <CRITICAL|HIGH|MEDIUM|LOW|INFO>

**Hallazgos:**

1. [SEVERIDAD] [Regla: ID] <descripción del problema>
   - Por qué es un problema: <explicación técnica breve>
   - Recomendación: <acción concreta>

2. [SEVERIDAD] [Regla: ID] ...

**¿Se recomienda ejecutar esta sentencia tal como está?** Sí / No / Con condiciones
```

Si la sentencia no tiene hallazgos, se reporta explícitamente:
`Sin hallazgos. La sentencia cumple las reglas evaluadas.` — no se inventan
observaciones para justificar la revisión (ver "Failure handling").

## Validation

Antes de entregar el reporte, la skill verifica:

- [ ] Toda sentencia del input aparece en el output (ninguna se omite
      silenciosamente).
- [ ] Cada hallazgo cita el ID de regla que lo originó (trazabilidad).
- [ ] Ningún hallazgo se reporta sin severidad asignada.
- [ ] Si `schema_context` no fue provisto, los hallazgos que dependen de él
      (ej. índices faltantes) están marcados como condicionales, no como
      hechos confirmados.
- [ ] No se afirma nada sobre datos reales de la tabla (volumen de filas,
      distribución de valores) que no haya sido provisto explícitamente.

## Failure handling

La skill **no inventa contexto** para completar un análisis. Comportamiento
explícito ante información insuficiente:

- **Sentencia no parseable / sintaxis irreconocible**: reportar
  `UNPARSEABLE` para esa sentencia específica, indicar qué la hace
  irreconocible, y continuar con el resto del script. No se asume qué
  "quiso decir" el autor.
- **Falta `schema_context` para evaluar índices o tipos de datos reales**:
  la skill reporta el hallazgo como condicional (ej. "esta columna en el
  WHERE probablemente necesita índice si la tabla es grande; no se puede
  confirmar sin conocer el volumen ni los índices existentes") en vez de
  afirmarlo como hecho.
- **Ambigüedad de intención** (ej. no está claro si un `DELETE` masivo es
  intencional o accidental): la skill no asume ninguna de las dos. Reporta
  el riesgo objetivo (severidad CRITICAL si no hay WHERE efectivo) y pide
  confirmación explícita de intención antes de recomendar ejecución.
- **Dialecto no soportado explícitamente**: si `dialect` no es reconocido,
  la skill aplica las reglas genéricas (ANSI SQL) y advierte que ciertas
  reglas específicas de motor (ej. sintaxis de índices en MySQL vs Postgres)
  no pudieron evaluarse.
- **Input vacío o sin SQL**: la skill no genera un reporte con hallazgos
  ficticios. Responde que no hay SQL identificable para revisar.

En todos los casos anteriores, la skill prioriza decir "no tengo suficiente
información para confirmar X" sobre inventar una conclusión.
