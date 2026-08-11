# Test 01

**Categoría:** Happy path

## Input

```sql
SELECT id, email, created_at
FROM users
WHERE status = 'active'
  AND created_at >= '2024-01-01'
ORDER BY created_at DESC
LIMIT 50;
```

## Expected behavior

La skill no debe generar hallazgos artificiales. La sentencia tiene columnas
explícitas, filtro selectivo, y LIMIT razonable. Se espera un reporte con
`Sin hallazgos. La sentencia cumple las reglas evaluadas.` o, a lo sumo,
hallazgos de severidad INFO sin recomendación de bloqueo.

## Actual behavior

La skill reportó: `Sin hallazgos. La sentencia cumple las reglas evaluadas.`
No se generaron falsos positivos sobre columnas, filtro o LIMIT.

## Pass / Fail

**PASS**

## Problem detected

Ninguno.

## Modification made to the skill

Ninguna. Este test se conserva como caso de control para detectar
regresiones futuras (si una modificación posterior empieza a marcar este
SQL como problemático, es señal de que una regla se volvió demasiado
agresiva).
