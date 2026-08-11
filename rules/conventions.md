# Reglas de Convenciones y Manejo de NULL

---

### CONV-01: Nombres de tablas/columnas poco descriptivos

```
IF identifier (table or column name) matches a low-information pattern
    (ejemplos: nombres de una sola letra como "a", "x", "t1", "col1",
     abreviaturas crípticas sin glosario asociado como "FCEML" en vez de "email")
THEN severity = LOW
AND finding = "Identificador poco descriptivo. Reduce la legibilidad y mantenibilidad del esquema/consulta."
AND recommendation = "Usar un nombre que describa el propósito del dato, siguiendo la convención del proyecto."
```

Nota: nombres con prefijos consistentes del propio dominio (ej. `FCEMAIL`,
`FCROLE`) no se marcan como LOW si el equipo documenta la convención en este
archivo; en ese caso se evalúa solo la consistencia, no el prefijo en sí.

### CONV-02: Inconsistencia de convención de nombres

```
IF sql_text mixes naming conventions without a documented reason
    (ej. snake_case y camelCase en la misma sentencia/esquema,
     mayúsculas y minúsculas mezcladas para el mismo tipo de identificador)
THEN severity = LOW
AND finding = "Convención de nombres inconsistente dentro del mismo script/esquema."
AND recommendation = "Unificar bajo una sola convención documentada en el proyecto."
```

### CONV-03: Palabras reservadas usadas como identificadores

```
IF identifier name matches a reserved SQL keyword
    (ej. "order", "group", "select", "table" usados como nombre de columna o tabla)
THEN severity = LOW
AND finding = "El identificador coincide con una palabra reservada del lenguaje SQL. Requiere escape constante (comillas/backticks) y es fuente de errores."
AND recommendation = "Renombrar el identificador para evitar colisión con palabras reservadas."
```

### CONV-04: Comparación de NULL con operadores de igualdad

```
IF WHERE clause compares a column to NULL using = or <>
    (ej. "WHERE columna = NULL", "WHERE columna <> NULL")
THEN severity = HIGH
AND finding = "Comparar con NULL usando = o <> siempre evalúa a UNKNOWN (no verdadero ni falso), por lo que la condición nunca selecciona filas del modo esperado por quien la escribió."
AND recommendation = "Usar IS NULL / IS NOT NULL en lugar de = NULL / <> NULL."
```

### CONV-05: NULL en columna con significado ambiguo

```
IF column allows NULL
AND the same column is also used elsewhere with a sentinel value
    (ej. 0, -1, '', 'N/A') to mean "sin valor"
THEN severity = MEDIUM
AND finding = "Uso mixto de NULL y valores centinela para representar 'ausencia de dato'. Genera lógica de negocio inconsistente (dos formas distintas de significar lo mismo)."
AND recommendation = "Elegir una única representación de 'sin valor' para la columna (NULL o un valor centinela documentado, no ambos)."
```

### CONV-06: Funciones de agregación que ignoran NULL sin advertencia

```
IF statement uses AVG() or SUM() over a column that allows NULL
AND there's no explicit handling (COALESCE, WHERE column IS NOT NULL documented as intentional)
THEN severity = INFO
AND finding = "AVG()/SUM() ignoran automáticamente los valores NULL, lo que puede alterar el resultado esperado si el usuario asumía que NULL cuenta como 0."
AND recommendation = "Confirmar si el comportamiento de exclusión de NULL es el deseado; usar COALESCE(columna, 0) si se requiere tratarlo como cero."
```

### CONV-07: NOT IN con subconsulta que puede contener NULL

```
IF statement uses "column NOT IN (subquery)"
AND subquery result can plausibly contain NULL
    (ej. selecciona una columna nullable sin filtrar IS NOT NULL)
THEN severity = HIGH
AND finding = "Si la subconsulta de NOT IN retorna algún NULL, la condición completa no selecciona ninguna fila (comportamiento contraintuitivo y silencioso)."
AND recommendation = "Filtrar explícitamente NULL en la subconsulta (WHERE columna IS NOT NULL) o usar NOT EXISTS en su lugar."
```

### CONV-08 (regla adicional del equipo): Falta de comentario en operación irreversible

```
IF statement.type IN (DROP, TRUNCATE, DELETE without WHERE-equivalent-safe)
AND statement is not preceded by a comment explaining the reason/ticket/author
THEN severity = LOW
AND finding = "Operación de alto impacto sin comentario que documente la razón o referencia (ticket, autor, fecha)."
AND recommendation = "Agregar un comentario que documente el motivo y contexto de la operación antes de ejecutarla."
```

### CONV-09 (regla adicional del equipo): Transacción abierta sin cierre explícito

```
IF script contains BEGIN / START TRANSACTION
AND no matching COMMIT or ROLLBACK is found later in the same script
THEN severity = HIGH
AND finding = "Transacción abierta sin COMMIT/ROLLBACK explícito en el script. Riesgo de locks colgados o cambios no confirmados."
AND recommendation = "Asegurar que toda transacción tenga un cierre explícito (COMMIT o ROLLBACK), incluyendo manejo de errores."
```
