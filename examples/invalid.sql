-- ============================================================
-- invalid.sql
-- Sentencias con violaciones claras y múltiples, pensadas para
-- disparar varias reglas de forma evidente (no ambigua).
-- ============================================================

-- SEC-01: DELETE sin WHERE (CRITICAL)
DELETE FROM users;

-- SEC-01 + PERF-01: UPDATE sin WHERE, además SELECT * en otra sentencia
UPDATE users SET status = 'inactive';

SELECT * FROM orders;

-- SEC-04: SQL Injection evidente por concatenación de input externo
-- (pseudocódigo representando construcción de query en aplicación)
-- query = "SELECT * FROM users WHERE email = '" + request.params.email + "'";

-- SEC-03: DROP sin ninguna salvaguarda ni comentario
DROP TABLE temp_import;

-- PERF-02: SELECT masivo sin LIMIT ni filtro selectivo
SELECT customer_id, order_date, total
FROM orders;

-- CONV-04: comparación de NULL con operador de igualdad
SELECT id, email
FROM users
WHERE deleted_at = NULL;

-- CONV-01: nombres poco descriptivos
CREATE TABLE t1 (
  a INT,
  b VARCHAR(10),
  x TEXT
);

-- PERF-07: tipo de dato deficiente para valor numérico
CREATE TABLE payments (
  id INT PRIMARY KEY,
  amount VARCHAR(20),   -- debería ser DECIMAL
  user_id VARCHAR(20)   -- debería ser INT/BIGINT (FK)
);

-- PERF-05: JOIN sin condición ON (producto cartesiano no documentado)
SELECT u.email, o.total
FROM users u, orders o;
