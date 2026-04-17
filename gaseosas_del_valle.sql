CREATE DATABASE IF NOT EXISTS gaseosas_del_valle;
USE gaseosas_del_valle;

CREATE TABLE sedes (
    id_sede           INT AUTO_INCREMENT PRIMARY KEY,
    nombre_sede       VARCHAR(100) NOT NULL,
    ubicacion         VARCHAR(200) NOT NULL,
    capacidad_almacenamiento INT NOT NULL,
    encargado         VARCHAR(100) NOT NULL
);

CREATE TABLE productos (
    id_producto   INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    categoria     VARCHAR(50)  NOT NULL,
    precio        DECIMAL(10,2) NOT NULL,
    volumen_ml    INT          NOT NULL,
    stock_actual  INT          NOT NULL DEFAULT 0,
    stock_minimo  INT          NOT NULL DEFAULT 0
);

CREATE TABLE clientes (
    id_cliente          INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo     VARCHAR(150) NOT NULL,
    identificacion      VARCHAR(20)  NOT NULL UNIQUE,
    direccion           VARCHAR(200),
    telefono            VARCHAR(20),
    correo_electronico  VARCHAR(100)
);

CREATE TABLE pedidos (
    id_pedido       INT AUTO_INCREMENT PRIMARY KEY,
    fecha_pedido    DATE         NOT NULL,
    id_cliente      INT          NOT NULL,
    id_sede         INT          NOT NULL,
    total_sin_iva   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_con_iva   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_sede)    REFERENCES sedes(id_sede)
);

CREATE TABLE detalle_pedido (
    id_detalle  INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido   INT          NOT NULL,
    id_producto INT          NOT NULL,
    cantidad    INT          NOT NULL,
    subtotal    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (id_pedido)   REFERENCES pedidos(id_pedido),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE auditoria_precios (
    id_auditoria    INT AUTO_INCREMENT PRIMARY KEY,
    id_producto     INT           NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo    DECIMAL(10,2) NOT NULL,
    fecha_cambio    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

DELIMITER $$

CREATE FUNCTION fn_calcular_total_con_iva(p_id_pedido INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_subtotal DECIMAL(12,2);
    SELECT COALESCE(SUM(subtotal), 0)
      INTO v_subtotal
      FROM detalle_pedido
     WHERE id_pedido = p_id_pedido;
    RETURN ROUND(v_subtotal * 1.19, 2);
END$$

CREATE FUNCTION fn_validar_stock(p_id_producto INT, p_cantidad INT)
RETURNS VARCHAR(100)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_stock INT;
    SELECT stock_actual INTO v_stock
      FROM productos
     WHERE id_producto = p_id_producto;
    IF v_stock >= p_cantidad THEN
        RETURN CONCAT('Stock suficiente. Disponible: ', v_stock, ' unidades.');
    ELSE
        RETURN CONCAT('Stock insuficiente. Disponible: ', v_stock,
                      ' unidades. Solicitadas: ', p_cantidad, '.');
    END IF;
END$$

DELIMITER ;

CREATE TRIGGER tr_actualizar_stock
AFTER INSERT ON detalle_pedido
FOR EACH ROW
BEGIN
    UPDATE productos
       SET stock_actual = stock_actual - NEW.cantidad
     WHERE id_producto = NEW.id_producto;
END$$

CREATE TRIGGER tr_auditar_cambio_precio
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO auditoria_precios (id_producto, precio_anterior, precio_nuevo, fecha_cambio)
        VALUES (OLD.id_producto, OLD.precio, NEW.precio, NOW());
    END IF;
END$$

DELIMITER ;

CREATE VIEW vista_resumen_pedidos_por_sede AS
SELECT
    s.id_sede,
    s.nombre_sede,
    s.ubicacion,
    COUNT(p.id_pedido)       AS total_pedidos,
    SUM(p.total_con_iva)     AS ventas_totales_con_iva
FROM sedes s
LEFT JOIN pedidos p ON s.id_sede = p.id_sede
GROUP BY s.id_sede, s.nombre_sede, s.ubicacion;

CREATE VIEW vista_productos_bajo_stock AS
SELECT
    id_producto,
    nombre,
    categoria,
    stock_actual,
    stock_minimo,
    (stock_minimo - stock_actual) AS unidades_faltantes
FROM productos
WHERE stock_actual <= stock_minimo;

CREATE VIEW vista_clientes_activos AS
SELECT
    c.id_cliente,
    c.nombre_completo,
    c.identificacion,
    c.telefono,
    c.correo_electronico,
    COUNT(p.id_pedido) AS total_pedidos
FROM clientes c
INNER JOIN pedidos p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nombre_completo, c.identificacion,
         c.telefono, c.correo_electronico;

INSERT INTO sedes (nombre_sede, ubicacion, capacidad_almacenamiento, encargado) VALUES
('Sede Girón Centro',       'Calle 5 #10-20, Girón',          5000, 'Carlos Ramírez'),
('Sede Bucaramanga Norte',  'Carrera 15 #30-45, Bucaramanga',  8000, 'Laura Mendoza'),
('Sede Piedecuesta Sur',    'Av. El Palmar #7-12, Piedecuesta',3000, 'Andrés Suárez');

INSERT INTO productos (nombre, categoria, precio, volumen_ml, stock_actual, stock_minimo) VALUES
('Coca-Cola 350ml',    'Cola',          2500.00, 350,  120, 20),
('Coca-Cola 600ml',    'Cola',          3500.00, 600,   80, 15),
('Pepsi 350ml',        'Cola',          2400.00, 350,   15, 20),  -- bajo stock
('Sprite 350ml',       'Lima-Limón',    2500.00, 350,  200, 30),
('Fanta Naranja 350ml','Naranja',       2500.00, 350,   10, 25),  -- bajo stock
('7UP 350ml',          'Lima-Limón',    2400.00, 350,   50, 10),
('Manzana Postobón',   'Manzana',       2600.00, 350,   90, 20),
('Uva Postobón',       'Uva',           2600.00, 350,    5, 15),  -- bajo stock
('Club Colombia',      'Malta',         3200.00, 330,   60, 10),
('Mr. Tea Limón',      'Té',            2800.00, 500,   40, 10);

INSERT INTO clientes (nombre_completo, identificacion, direccion, telefono, correo_electronico) VALUES
('Juan Carlos Pérez',      '13456789', 'Cra 10 #5-20, Girón',         '3001234567', 'jcperez@mail.com'),
('María Fernanda López',   '28345678', 'Cll 15 #8-30, Bucaramanga',   '3102345678', 'mflopez@mail.com'),
('Andrés Felipe Torres',   '91234567', 'Av. 5 #12-10, Piedecuesta',   '3203456789', 'aftorres@mail.com'),
('Claudia Patricia Niño',  '37891234', 'Cra 22 #18-40, Girón',        '3154567890', 'cpnino@mail.com'),
('Roberto Castellanos',    '17654321', 'Cll 30 #25-15, Bucaramanga',  '3005678901', 'rcastellanos@mail.com'),
('Diana Marcela Rueda',    '46789123', 'Cra 8 #3-55, Girón',          '3016789012', 'dmrueda@mail.com'),
('Luis Ernesto Vargas',    '19876543', 'Cll 50 #40-20, Bucaramanga',  '3177890123', 'levargas@mail.com');

INSERT INTO pedidos (fecha_pedido, id_cliente, id_sede, total_sin_iva, total_con_iva) VALUES
('2024-01-10', 1, 1,  25000.00,  29750.00),
('2024-01-15', 2, 2,  42000.00,  49980.00),
('2024-02-05', 1, 1,  18000.00,  21420.00),
('2024-02-20', 3, 3,  35000.00,  41650.00),
('2024-03-08', 4, 1,  12000.00,  14280.00),
('2024-03-22', 2, 2,  60000.00,  71400.00),
('2024-04-01', 5, 2,  28000.00,  33320.00),
('2024-04-18', 1, 1,  15000.00,  17850.00),
('2024-05-10', 6, 3,  22000.00,  26180.00),
('2024-05-25', 3, 3,  47000.00,  55930.00),
('2024-06-03', 7, 2,  33000.00,  39270.00),
('2024-06-14', 4, 1,  19000.00,  22610.00);
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, subtotal) VALUES
(1,  1, 5, 12500.00),
(1,  4, 5, 12500.00),
(2,  2, 6, 21000.00),
(2,  7, 8, 20800.00),
(3,  6, 7, 16800.00),
(4,  9, 5, 16000.00),
(4,  3, 8, 19200.00),
(5,  5, 4, 10000.00),
(6,  1,10, 25000.00),
(6,  2,10, 35000.00),
(7,  7, 8, 20800.00),
(7,  8, 2,  5200.00),
(8,  4, 6, 15000.00),
(9,  6, 9, 21600.00),
(10, 9, 8, 25600.00),
(10, 2, 6, 21000.00),
(11, 1, 6, 15000.00),
(11, 10,6, 16800.00),
(12, 5, 3,  7500.00),
(12, 4, 4, 10000.00);

SELECT
    id_producto,
    nombre,
    categoria,
    stock_actual,
    stock_minimo
FROM productos
WHERE stock_actual < stock_minimo;

SELECT
    p.id_pedido,
    p.fecha_pedido,
    c.nombre_completo AS cliente,
    s.nombre_sede     AS sede,
    p.total_con_iva
FROM pedidos p
JOIN clientes c ON p.id_cliente = c.id_cliente
JOIN sedes    s ON p.id_sede    = s.id_sede
WHERE p.fecha_pedido BETWEEN '2024-02-01' AND '2024-04-30'
ORDER BY p.fecha_pedido;

SELECT
    pr.id_producto,
    pr.nombre,
    pr.categoria,
    SUM(dp.cantidad)  AS total_unidades_vendidas,
    SUM(dp.subtotal)  AS total_ingresos
FROM detalle_pedido dp
JOIN productos pr ON dp.id_producto = pr.id_producto
GROUP BY pr.id_producto, pr.nombre, pr.categoria
ORDER BY total_unidades_vendidas DESC;

SELECT
    c.id_cliente,
    c.nombre_completo,
    c.telefono,
    COUNT(p.id_pedido) AS cantidad_pedidos,
    SUM(p.total_con_iva) AS total_compras
FROM clientes c
LEFT JOIN pedidos p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nombre_completo, c.telefono
ORDER BY cantidad_pedidos DESC;

SELECT
    id_cliente,
    nombre_completo,
    identificacion,
    telefono,
    correo_electronico
FROM clientes
WHERE nombre_completo LIKE '%López%'; 

SELECT
    id_producto,
    nombre,
    categoria,
    precio,
    stock_actual
FROM productos
WHERE categoria IN ('Cola', 'Lima-Limón', 'Naranja')
ORDER BY categoria, nombre;

SELECT
    c.id_cliente,
    c.nombre_completo,
    c.telefono,
    c.correo_electronico,
    COUNT(p.id_pedido) AS total_pedidos
FROM clientes c
JOIN pedidos p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nombre_completo, c.telefono, c.correo_electronico
HAVING COUNT(p.id_pedido) = (
    SELECT MAX(cnt)
    FROM (
        SELECT COUNT(id_pedido) AS cnt
        FROM pedidos
        GROUP BY id_cliente
    ) AS sub
);

SELECT
    s.id_sede,
    s.nombre_sede,
    s.ubicacion,
    COUNT(p.id_pedido)       AS total_pedidos,
    SUM(p.total_sin_iva)     AS suma_sin_iva,
    SUM(p.total_con_iva)     AS suma_con_iva
FROM sedes s
LEFT JOIN pedidos p ON s.id_sede = p.id_sede
GROUP BY s.id_sede, s.nombre_sede, s.ubicacion
ORDER BY total_pedidos DESC;

SELECT fn_calcular_total_con_iva(1) AS total_iva_pedido_1;

SELECT fn_validar_stock(1, 50)  AS validacion_coca350_50uds;

SELECT fn_validar_stock(3, 5)   AS validacion_pepsi_5uds;

SELECT * FROM vista_productos_bajo_stock;

SELECT * FROM vista_resumen_pedidos_por_sede;

SELECT * FROM vista_clientes_activos;
