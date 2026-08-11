# Test 04

**Categoría:** Información insuficiente

## Input

```sql
UPDATE orders SET status = 'shipped' WHERE region = 'north';
```

(Sin `schema_context`: no se sabe si `region` está indexada, ni cuántas
filas tiene `orders`, ni qué proporción de filas tiene `region = 'north'`.)

## Expected behavior

La skill debe reconocer que no puede confirmar dos cosas: (a) si la
condición `region = 'north'` es de alta o baja selectividad (podría ser el
90% de las filas o el 2%), y (b) si existe un índice sobre `region`. En
ambos casos debe reportar explícitamente la incertidumbre en vez de asumir
un escenario y afirmarlo como hecho — sin inventar contexto, según la
sección "Failure handling" de `SKILL.md`.

## Actual behavior

La skill reportó: la sentencia tiene una condición `WHERE` sintácticamente
válida (no dispara SEC-01/SEC-02), pero no puede determinar la selectividad
real de `region = 'north'` ni la existencia de un índice sin
`schema_context`. Marcó el hallazgo de índice (PERF-03) como severidad INFO
con la nota "no se puede confirmar sin schema_context" en vez de HIGH, y no
afirmó nada sobre el volumen de filas afectadas. Solicitó explícitamente
`schema_context` o `execution_context` para dar una evaluación más precisa
antes de dar una recomendación de bloqueo o aprobación.

## Pass / Fail

**PASS**

## Problem detected

Ninguno. Este comportamiento es el esperado desde el diseño original de
"Failure handling" — se incluye como test explícito porque es un criterio
de evaluación con penalización (-10 puntos si la skill inventa información
cuando faltan datos).

## Modification made to the skill

Ninguna funcional. Se añadió este test para dejar evidencia documentada de
que el comportamiento de "no inventar contexto" fue verificado, no solo
declarado en `SKILL.md`.
