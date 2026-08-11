# Test 02

**Categoría:** Error evidente (múltiples violaciones claras)

## Input

```sql
DELETE FROM users;

UPDATE users SET status = 'inactive';

SELECT * FROM orders;
```

## Expected behavior

Cada una de las tres sentencias debe generar hallazgos:

1. `DELETE FROM users;` → SEC-01, severidad CRITICAL, no se recomienda ejecutar.
2. `UPDATE users SET status = 'inactive';` → SEC-01, severidad CRITICAL, no se recomienda ejecutar.
3. `SELECT * FROM orders;` → PERF-01 (SELECT *) severidad MEDIUM, y PERF-02
   (ausencia de LIMIT sin filtro selectivo) severidad MEDIUM.

## Actual behavior

Las tres sentencias fueron reportadas con las severidades esperadas. El
`DELETE` y el `UPDATE` fueron marcados CRITICAL citando la regla SEC-01 y
con recomendación explícita de no ejecutar. El `SELECT *` fue marcado
MEDIUM citando PERF-01 y PERF-02 simultáneamente.

## Pass / Fail

**PASS**

## Problem detected

Ninguno en la primera ejecución.

## Modification made to the skill

Ninguna.
