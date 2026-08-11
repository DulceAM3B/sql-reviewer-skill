# Reglas de Seguridad

Todas las reglas siguen el formato `IF ... THEN severity = ... AND finding = ...`.
Estas reglas son deterministas: dado el mismo input, siempre producen el
mismo resultado. La evaluación de intención (¿es esto realmente peligroso en
la práctica?) ocurre en el paso 5 del procedimiento en `SKILL.md`, no aquí.

---

### SEC-01: DELETE / UPDATE sin WHERE

```
IF statement.type IN (DELETE, UPDATE)
AND statement.WHERE is absent
THEN severity = CRITICAL
AND finding = "Sentencia destructiva/mutante sin condición WHERE. Afecta el 100% de las filas de la tabla."
AND recommendation = "No ejecutar. Agregar condición WHERE explícita que acote las filas objetivo."
```

### SEC-02: WHERE semánticamente vacío (evasión de SEC-01)

```
IF statement.type IN (DELETE, UPDATE)
AND statement.WHERE exists
AND condition is a tautology for every row
    (ejemplos: "1=1", "1<>0", "col = col", "'a'='a'", "col LIKE '%'" sin otros predicados AND)
THEN severity = CRITICAL
AND finding = "La cláusula WHERE existe sintácticamente pero no filtra ninguna fila. Equivalente en efecto a SEC-01."
AND recommendation = "No ejecutar. Reemplazar por una condición que realmente acote filas."
```

Nota: esta regla existe específicamente porque una regla que solo verifica
"¿existe la palabra WHERE?" es evadible. Ver `tests/test-05.md` (adversarial)
y el ejemplo de Red Team del enunciado: `DELETE FROM TA_USERS WHERE 1 = 1;`.

### SEC-03: Operaciones destructivas de esquema sin salvaguarda

```
IF statement.type IN (DROP TABLE, DROP DATABASE, TRUNCATE)
THEN severity = CRITICAL
AND finding = "Operación destructiva e irreversible sobre esquema o datos completos de la tabla."
AND recommendation = "Confirmar explícitamente la intención. Verificar backup previo. Considerar soft-delete o renombrado en vez de DROP si es posible."
```

### SEC-04: Concatenación de strings para construir SQL (riesgo de SQL Injection)

```
IF sql_text contains string concatenation building a query
    (patrones: "'" + variable + "'", CONCAT(... , input_variable , ...) dentro de una sentencia
     ejecutable, interpolación de variables directamente en el texto de la query)
AND concatenated value appears to originate from external/user input
    (nombres típicos: request, input, param, user_input, form, arg)
THEN severity = CRITICAL
AND finding = "Construcción de SQL por concatenación de datos externos. Vector de SQL Injection."
AND recommendation = "Usar sentencias preparadas (prepared statements) o parámetros bindeados. Nunca concatenar input externo directamente en el texto SQL."
```

```
IF sql_text contains string concatenation
AND origin of concatenated value cannot be determined from the input
THEN severity = HIGH
AND finding = "Concatenación de valores en SQL sin poder confirmar el origen del dato. Riesgo potencial de SQL Injection."
AND note = "No se puede confirmar con certeza sin más contexto (ver Failure handling en SKILL.md)."
```

### SEC-05: UPDATE/DELETE con condición WHERE amplia pero no trivial

```
IF statement.type IN (DELETE, UPDATE)
AND statement.WHERE exists
AND condition uses a broad/low-selectivity predicate
    (ejemplos: comparación sobre columna booleana o de pocos valores posibles,
     "WHERE status IS NOT NULL" en tabla donde casi todo tiene status,
     "WHERE FCEMAIL LIKE '%'" — coincide con cualquier email no nulo)
THEN severity = HIGH
AND finding = "La condición WHERE es técnicamente selectiva pero de bajo poder de filtrado; puede afectar la gran mayoría de las filas."
AND recommendation = "Confirmar si el alcance amplio es intencional. Considerar acotar por rango, ID, o fecha."
```

Ejemplo del enunciado que activa esta regla:
`UPDATE TA_USERS SET FCROLE = 'ADMIN' WHERE FCEMAIL LIKE '%';` — el `LIKE '%'`
coincide con cualquier valor no nulo, por lo que en la práctica no filtra
nada útil; se trata como equivalente a SEC-02 si no hay ningún otro
predicado AND que acote.

### SEC-06: Credenciales o secretos embebidos en el SQL

```
IF sql_text contains what appears to be a hardcoded password, API key, or token
    (patrones: "PASSWORD = '...'", "IDENTIFIED BY '...'", strings con apariencia
     de secreto en un CREATE USER / GRANT)
THEN severity = HIGH
AND finding = "Posible credencial o secreto embebido en texto plano dentro del script SQL."
AND recommendation = "Externalizar credenciales a un gestor de secretos. No versionar contraseñas en scripts SQL."
```

### SEC-07: Permisos excesivos (GRANT amplio)

```
IF statement.type = GRANT
AND privilege includes ALL PRIVILEGES
   OR scope is a wildcard over all databases/tables (ej. "ON *.*")
THEN severity = HIGH
AND finding = "Otorgamiento de privilegios excesivamente amplio."
AND recommendation = "Aplicar principio de menor privilegio: otorgar solo los permisos y el alcance estrictamente necesarios."
```

### SEC-08: Comentarios que sugieren evasión intencional

```
IF sql_text contains SQL comment syntax (--, /* */) positioned in a way
   consistent with a classic injection payload
   (ej. "' OR '1'='1' --", "'; DROP TABLE ...; --")
THEN severity = CRITICAL
AND finding = "El patrón corresponde a un payload clásico de SQL Injection, no a una sentencia legítima."
AND recommendation = "Rechazar. Esta entrada no debe tratarse como SQL de aplicación legítimo; reportar como intento de inyección."
```
