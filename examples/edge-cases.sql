-- Caso 1: WHERE presente pero trivialmente verdadero (SEC-02)
DELETE FROM users WHERE 1 = 1;

-- Caso 2: LIMIT presente pero sin efecto práctico (PERF-02b)
SELECT * FROM users LIMIT 1000000000;

-- Caso 3: WHERE con condición de baja selectividad que en la práctica
UPDATE users SET role = 'admin' WHERE email LIKE '%';

-- Caso 4: WHERE presente y "selectivo" en apariencia, pero sobre una
-- columna booleana con solo dos valores posibles, en una tabla donde
-- casi todas las filas comparten el mismo valor (SEC-05).
-- Ejemplo: 99% de las filas tiene is_deleted = false
UPDATE users SET notified = true WHERE is_deleted = false;

-- Caso 5: subconsulta NOT IN que puede contener NULL de forma silenciosa (CONV-07)
-- Si algún email en 'blocked_emails' es NULL, este DELETE no borra NADA,
-- sin ningún error visible.
DELETE FROM users
WHERE email NOT IN (SELECT email FROM blocked_emails);

-- Caso 6: JOIN con ON presente pero que no acota relación real
-- (el ON existe sintácticamente, pero la condición es una tautología
-- equivalente a un CROSS JOIN disfrazado)
SELECT u.email, o.total
FROM users u
JOIN orders o ON 1 = 1;

-- Caso 7: transacción con COMMIT presente, pero dentro de una rama
-- condicional que puede no ejecutarse nunca en ciertos motores/lógicas
-- de aplicación (riesgo de transacción colgada en la práctica, aunque
-- el texto "tiene" COMMIT en alguna parte del script).
BEGIN;
UPDATE inventory SET stock = stock - 1 WHERE product_id = 55;
-- COMMIT solo ocurre si la aplicación confirma el pago; si falla antes,
-- la transacción queda abierta indefinidamente.
