# Reglas de Rendimiento

---

### PERF-01: SELECT *

```
IF statement.type = SELECT
AND column list = "*"
THEN severity = MEDIUM
AND finding = "SELECT * trae todas las columnas, incluidas las no necesarias. Aumenta I/O, tráfico de red y rompe si el esquema cambia."
AND recommendation = "Listar explícitamente las columnas requeridas."
```

```
IF statement.type = SELECT
AND column list = "*"
AND statement includes JOIN with 2 or more tables
THEN severity = HIGH
AND finding = "SELECT * combinado con JOIN multiplica el problema: trae columnas duplicadas o irrelevantes de todas las tablas unidas."
AND recommendation = "Listar explícitamente las columnas requeridas, prefijadas por tabla/alias."
```

### PERF-02: Ausencia de LIMIT en consulta potencialmente masiva

```
IF statement.type = SELECT
AND statement.LIMIT is absent
AND (statement has no WHERE clause OR WHERE clause is low-selectivity)
AND table is not known to be small (o schema_context no lo descarta)
THEN severity = MEDIUM
AND finding = "Consulta sin LIMIT y sin filtro selectivo. Riesgo de traer un volumen de filas no acotado."
AND recommendation = "Agregar LIMIT explícito o un WHERE selectivo, según el propósito de la consulta."
```

### PERF-02b: LIMIT presente pero con valor absurdamente alto (evasión de PERF-02)

```
IF statement.type = SELECT
AND statement.LIMIT exists
AND LIMIT value >= a threshold that exceeds any plausible page size
    (ej. LIMIT 1000000000, LIMIT 999999999)
THEN severity = MEDIUM
AND finding = "LIMIT presente sintácticamente pero con un valor tan alto que no cumple su función de acotar el resultado."
AND recommendation = "Usar un LIMIT realista para el caso de uso (paginación, muestreo), o justificar explícitamente por qué se requiere ese volumen."
```

Ejemplo del enunciado que activa esta regla:
`SELECT * FROM TA_USERS LIMIT 1000000000;` — el LIMIT existe, pero no
cumple ninguna función práctica de acotar resultados.

### PERF-03: Falta de índice probable en columna de WHERE/JOIN

```
IF statement includes WHERE or JOIN ON condition over column X
AND schema_context is provided
AND column X has no index defined in schema_context
AND table is not known to be small
THEN severity = HIGH
AND finding = "La columna X se usa para filtrar/unir pero no tiene índice conocido. Probable table scan completo."
AND recommendation = "Evaluar la creación de un índice sobre X (o índice compuesto si se usa junto a otras columnas del mismo WHERE)."
```

```
IF statement includes WHERE or JOIN ON condition over column X
AND schema_context is NOT provided
THEN severity = INFO
AND finding = "No se puede confirmar si la columna X tiene índice: no se proporcionó schema_context."
AND recommendation = "Verificar manualmente si existe índice sobre X antes de ejecutar en tablas grandes."
```

### PERF-04: Funciones aplicadas sobre columnas indexadas en WHERE (sargability)

```
IF WHERE clause applies a function to a column
    (ej. "WHERE YEAR(fecha) = 2024", "WHERE UPPER(email) = '...'", "WHERE fecha + 1 > NOW()")
THEN severity = MEDIUM
AND finding = "Aplicar una función sobre la columna en el WHERE impide el uso de índices sobre esa columna (consulta no sargable)."
AND recommendation = "Reescribir la condición para dejar la columna 'limpia', moviendo la operación al valor de comparación (ej. usar un rango de fechas en vez de YEAR(fecha))."
```

### PERF-05: JOIN sin condición ON explícita (producto cartesiano)

```
IF statement includes JOIN
AND ON / USING clause is absent
AND join is not explicitly a documented CROSS JOIN
THEN severity = CRITICAL
AND finding = "JOIN sin condición de unión: genera un producto cartesiano entre las tablas."
AND recommendation = "Agregar condición ON explícita, o usar CROSS JOIN de forma intencional y documentada si el producto cartesiano es deseado."
```

### PERF-06: Subconsultas correlacionadas evitables en SELECT

```
IF statement includes a correlated subquery in the SELECT column list
   that references the outer query row-by-row
AND an equivalent JOIN or window function would achieve the same result
THEN severity = MEDIUM
AND finding = "Subconsulta correlacionada ejecutada por cada fila del resultado externo. Costo O(n*m) evitable."
AND recommendation = "Evaluar reescritura como JOIN o función de ventana (window function)."
```

### PERF-07: Tipos de datos deficientes

```
IF column definition uses TEXT/VARCHAR(MAX) for a value with a known bounded domain
    (ej. email, código postal, estado de dos letras, teléfono)
THEN severity = MEDIUM
AND finding = "Tipo de dato sobredimensionado para el dominio real del valor. Afecta almacenamiento e índices."
AND recommendation = "Usar un tipo acotado (ej. VARCHAR(255) para email, CHAR(2) para código de país)."
```

```
IF column intended to store numeric identifiers or amounts is defined as VARCHAR/TEXT
THEN severity = MEDIUM
AND finding = "Valor numérico almacenado como texto. Impide operaciones aritméticas/comparación numérica eficiente e integridad de tipo."
AND recommendation = "Usar un tipo numérico apropiado (INT, BIGINT, DECIMAL según el caso)."
```

### PERF-08: ORDER BY sin índice de soporte en resultados grandes

```
IF statement.type = SELECT
AND statement includes ORDER BY on column X
AND schema_context is provided
AND column X has no index
AND no LIMIT is present or the expected result set is large
THEN severity = MEDIUM
AND finding = "ORDER BY sobre columna sin índice en un resultado potencialmente grande requiere ordenamiento en memoria/disco (filesort)."
AND recommendation = "Evaluar índice sobre la(s) columna(s) de ORDER BY, especialmente si se usa junto con LIMIT para paginación."
```
