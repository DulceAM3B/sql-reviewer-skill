# Test 03

**Categoría:** Edge case (parece correcto superficialmente, pero contiene un problema)

## Input

```sql
DELETE FROM users
WHERE email NOT IN (SELECT email FROM blocked_emails);
```

## Expected behavior

A primera vista la sentencia "tiene WHERE" y parece segura. Sin embargo, si
la subconsulta `SELECT email FROM blocked_emails` puede retornar algún
`NULL` (la columna `email` de esa tabla es nullable y no se filtra
`IS NOT NULL`), el `NOT IN` completo no selecciona ninguna fila — de forma
silenciosa, sin error. La skill debe detectar esto vía CONV-07, con
severidad HIGH, y explicar el comportamiento contraintuitivo de `NOT IN`
con NULL.

## Actual behavior

La skill identificó el patrón `NOT IN (subquery)` y, al no tener
`schema_context` que confirmara si `blocked_emails.email` permite NULL,
reportó el hallazgo CONV-07 como advertencia condicional: "la subconsulta
puede contener NULL; si eso ocurre, el DELETE no eliminará ninguna fila de
forma silenciosa. No se puede confirmar sin conocer el esquema de
`blocked_emails`." Recomendó usar `NOT EXISTS` o filtrar `IS NOT NULL`
explícitamente en la subconsulta.

## Pass / Fail

**PASS**

## Problem detected

En la primera versión de la regla CONV-07, la skill exigía confirmar con
certeza que la columna permitía NULL antes de generar el hallazgo, lo que
la hacía inútil en ausencia de `schema_context` (el caso más común). Se
corrigió para que, sin `schema_context`, el hallazgo se reporte igual pero
como advertencia condicional en vez de omitirse.

## Modification made to the skill

Se ajustó `rules/conventions.md` (CONV-07) y la sección "Failure handling"
de `SKILL.md` para que la ausencia de `schema_context` degrade la certeza
del hallazgo, pero nunca lo elimine cuando el patrón sintáctico de riesgo
(`NOT IN` + subconsulta sobre columna nullable no filtrada) está presente.
