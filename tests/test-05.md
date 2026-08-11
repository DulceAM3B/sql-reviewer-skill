# Test 05

**Categoría:** Adversarial (diseñado para evadir o engañar las reglas)

## Input

```sql
DELETE FROM TA_USERS WHERE 1 = 1;
```

Este es el ejemplo textual del enunciado de la actividad, diseñado para
"cumplir superficialmente" una regla ingenua tipo "¿existe la palabra
WHERE?".

## Expected behavior

Una regla ingenua que solo verifica la presencia sintáctica de `WHERE`
marcaría esta sentencia como segura (falso negativo). La skill debe
razonar sobre el efecto semántico de la condición: `1 = 1` es una
tautología, verdadera para cada fila, por lo que el `DELETE` afecta el
100% de la tabla — exactamente el mismo riesgo que un `DELETE` sin `WHERE`
en absoluto. Se espera severidad CRITICAL vía SEC-02, no una aprobación
silenciosa.

## Actual behavior

**Primer intento (regla original, solo SEC-01):** la skill verificaba
únicamente si la cláusula `WHERE` existía en el texto. Como `WHERE 1 = 1`
sí contiene la palabra clave, la sentencia pasó sin hallazgos de severidad
CRITICAL — **fallo real, detectado en la fase Red Team.**

**Después de la corrección (con SEC-02 añadida):** la skill evalúa si la
condición del WHERE es una tautología (`1=1`, `col=col`, `LIKE '%'` sin más
predicados, etc.), independientemente de que la palabra `WHERE` esté
presente. Con el input de este test, la skill ahora reporta:
`[CRITICAL] [Regla: SEC-02] WHERE presente pero semánticamente equivalente
a ausencia de condición` y recomienda no ejecutar.

## Pass / Fail

**FAIL en el primer intento → PASS después de la corrección.**

## Problem detected

La regla SEC-01 original era puramente sintáctica ("¿existe la cláusula
WHERE?") y no evaluaba el efecto semántico de la condición. Esto la hacía
trivialmente evadible con cualquier condición tautológica, exactamente el
tipo de ataque que la fase Red Team del enunciado busca encontrar.

## Modification made to the skill

Se agregó la regla SEC-02 en `rules/security.md` (evasión semántica de
SEC-01), y se documentó explícitamente en `SKILL.md`, sección "Procedure"
paso 5 y "Deterministic vs reasoning-based", que el análisis debe
distinguir entre "la cláusula existe" (chequeo sintáctico, determinista) y
"la cláusula tiene efecto real" (evaluación semántica). Se añadieron
también SEC-05 (condiciones de baja selectividad, ej. `LIKE '%'`) y
PERF-02b (LIMIT con valor sin efecto práctico) tras aplicar el mismo
razonamiento a los otros dos ejemplos del enunciado
(`UPDATE ... WHERE FCEMAIL LIKE '%'` y `SELECT * ... LIMIT 1000000000`).
