-- SIGIH | 18 - Datos de demostración
-- ----------------------------------------------------------------------------
-- Carga un catálogo realista para que el sistema no arranque vacío:
--   5 categorías · 8 áreas · 21 productos · 43 movimientos
--
-- Reglas que respeta:
--   * El stock SOLO se mueve con sp_Movimientos_RegistrarEntrada/Salida,
--     de modo que Lotes y Movimientos quedan consistentes y se cumplen
--     CK_Mov_Area y CK_Mov_Cambio.
--   * Es idempotente: los productos se guardan por `codigo`, las entradas y
--     salidas por `motivo`. Ejecutarlo dos veces no duplica nada.
--   * No borra ni modifica datos ajenos a la demostración.
--   * Deja 3 productos en stock bajo, 2 lotes por vencer y 1 lote vencido
--     para que Alertas y Dashboard tengan contenido.
-- ----------------------------------------------------------------------------

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @id_admin       INT,
        @id_almacen     INT,
        @id_producto    INT,
        @id_lote        INT,
        @id_area        INT,
        @id_usuario     INT,
        @id_movimiento  INT,
        @cantidad       INT,
        @motivo         NVARCHAR(200),
        @numero_lote    NVARCHAR(50),
        @vence          DATE,
        @dias           INT;

DECLARE @res TABLE
(
    id_movimiento  INT,
    id_lote        INT,
    stock_anterior INT,
    stock_posterior INT
);

-- ============================================================================
-- 0. Usuarios de la demostración
-- ============================================================================

SET @id_admin = (SELECT id_usuario FROM dbo.Usuarios WHERE email = N'admin.desarrollo@sigih.test');

IF @id_admin IS NULL
    THROW 51901, N'No existe el administrador inicial. Ejecute antes 16_admin_inicial.sql.', 1;

-- Usuario de almacén con la misma contraseña de desarrollo (Admin.2026!).
IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE email = N'almacen.demo@sigih.test')
BEGIN
    INSERT dbo.Usuarios (nombre, email, password_hash, activo)
    SELECT N'Jefe de Almacén', N'almacen.demo@sigih.test', password_hash, 1
    FROM dbo.Usuarios
    WHERE email = N'admin.desarrollo@sigih.test';
END;

SET @id_almacen = (SELECT id_usuario FROM dbo.Usuarios WHERE email = N'almacen.demo@sigih.test');

IF @id_almacen IS NOT NULL
   AND EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = N'ALMACEN')
BEGIN
    INSERT dbo.UsuariosRoles (id_usuario, id_rol)
    SELECT @id_almacen, r.id_rol
    FROM dbo.Roles r
    WHERE r.nombre = N'ALMACEN'
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.UsuariosRoles ur
          WHERE ur.id_usuario = @id_almacen AND ur.id_rol = r.id_rol
      );
END;

-- ============================================================================
-- 1. Categorías y áreas
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Medicamentos')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Medicamentos', N'Medicamentos de uso hospitalario');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material médico')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material médico', N'Insumos y material de atención médica');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material de laboratorio')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material de laboratorio', N'Insumos y reactivos de laboratorio clínico');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Limpieza hospitalaria')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Limpieza hospitalaria', N'Productos de desinfección y limpieza');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Equipos y dispositivos médicos')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Equipos y dispositivos médicos', N'Equipos biomédicos y dispositivos de medición');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Emergencia')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Emergencia');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Hospitalización')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Hospitalización');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Consultorios externos')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Consultorios externos');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Laboratorio')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Laboratorio');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Quirófano')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Quirófano');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'UCI')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'UCI');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Pediatría')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Pediatría');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Farmacia')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Farmacia');

-- ============================================================================
-- 2. Productos
-- ============================================================================

DECLARE @productos TABLE
(
    codigo               NVARCHAR(30)  NOT NULL,
    nombre               NVARCHAR(150) NOT NULL,
    categoria            NVARCHAR(100) NOT NULL,
    descripcion          NVARCHAR(500) NULL,
    unidad_medida        NVARCHAR(30)  NOT NULL,
    precio_unitario      DECIMAL(12,2) NOT NULL,
    stock_minimo         INT           NOT NULL,
    maneja_lotes         BIT           NOT NULL,
    requiere_vencimiento BIT           NOT NULL
);

INSERT @productos
    (codigo, nombre, categoria, descripcion, unidad_medida, precio_unitario,
     stock_minimo, maneja_lotes, requiere_vencimiento)
VALUES
    -- Medicamentos
    (N'MED-PAR-500', N'Paracetamol 500 mg', N'Medicamentos',
     N'Analgésico y antipirético de primera línea', N'tableta', 0.15, 800, 1, 1),
    (N'MED-IBU-400', N'Ibuprofeno 400 mg', N'Medicamentos',
     N'Antiinflamatorio no esteroideo', N'tableta', 0.20, 600, 1, 1),
    (N'MED-AMO-500', N'Amoxicilina 500 mg', N'Medicamentos',
     N'Antibiótico de amplio espectro', N'cápsula', 0.45, 400, 1, 1),
    (N'MED-OME-20', N'Omeprazol 20 mg', N'Medicamentos',
     N'Inhibidor de la bomba de protones', N'cápsula', 0.30, 300, 1, 1),
    (N'MED-SSF-09', N'Solución fisiológica 0.9% 500 ml', N'Medicamentos',
     N'Solución salina isotónica para infusión', N'frasco', 3.80, 150, 1, 1),
    (N'MED-DEX-05', N'Dextrosa 5% 500 ml', N'Medicamentos',
     N'Solución glucosada para infusión', N'frasco', 4.20, 120, 1, 1),
    (N'MED-ADR-01', N'Adrenalina 1 mg/ml', N'Medicamentos',
     N'Vasopresor para emergencias', N'ampolla', 5.50, 60, 1, 1),

    -- Material médico
    (N'MAT-GUA-NIT-M', N'Guantes de nitrilo M', N'Material médico',
     N'Caja con 100 guantes de examen', N'caja', 24.90, 40, 1, 1),
    (N'MAT-JER-10', N'Jeringa 10 ml', N'Material médico',
     N'Jeringa desechable con aguja', N'unidad', 0.35, 500, 1, 0),
    (N'MAT-GAS-10', N'Gasa estéril 10x10', N'Material médico',
     N'Paquete con 10 gasas estériles', N'paquete', 1.10, 300, 1, 1),
    (N'MAT-AGU-21', N'Aguja hipodérmica 21G', N'Material médico',
     N'Aguja desechable para inyección', N'unidad', 0.12, 800, 1, 0),
    (N'MAT-CAT-20', N'Catéter venoso 20G', N'Material médico',
     N'Catéter periférico para canalización', N'unidad', 1.85, 200, 1, 0),
    (N'MAT-SUT-30', N'Sutura nylon 3-0', N'Material médico',
     N'Hilo de sutura no absorbible', N'unidad', 9.75, 50, 1, 1),

    -- Material de laboratorio
    (N'LAB-TUB-EDTA', N'Tubo EDTA tapa lila', N'Material de laboratorio',
     N'Tubo para hemograma con anticoagulante', N'unidad', 0.55, 400, 1, 1),
    (N'LAB-TUB-SER', N'Tubo seco tapa roja', N'Material de laboratorio',
     N'Tubo para química sanguínea sin anticoagulante', N'unidad', 0.50, 400, 1, 1),
    (N'LAB-REA-GLU', N'Reactivo glucosa oxidasa 500 ml', N'Material de laboratorio',
     N'Reactivo para determinación de glucosa', N'frasco', 38.00, 12, 1, 1),
    (N'LAB-PAP-FIL', N'Papel filtro cualitativo caja x100', N'Material de laboratorio',
     N'Papel filtro para laboratorio', N'caja', 12.50, 15, 0, 0),

    -- Limpieza hospitalaria
    (N'LIM-HIP-05', N'Hipoclorito de sodio 5% 1 L', N'Limpieza hospitalaria',
     N'Desinfectante de superficies', N'galón', 6.40, 60, 0, 0),
    (N'LIM-ALC-70', N'Alcohol etílico 70% 1 L', N'Limpieza hospitalaria',
     N'Antiséptico y desinfectante', N'galón', 7.20, 60, 0, 0),

    -- Equipos y dispositivos médicos
    (N'EQP-TEN-DIG', N'Tensiómetro digital de brazo', N'Equipos y dispositivos médicos',
     N'Monitor de presión arterial automático', N'unidad', 185.00, 3, 0, 0),
    (N'EQP-TER-INF', N'Termómetro infrarrojo', N'Equipos y dispositivos médicos',
     N'Termómetro sin contacto para triaje', N'unidad', 95.00, 4, 0, 0);

INSERT dbo.Productos
    (id_categoria, codigo, nombre, descripcion, unidad_medida,
     precio_unitario, stock_minimo, maneja_lotes, requiere_vencimiento, activo)
SELECT c.id_categoria,
       p.codigo,
       p.nombre,
       p.descripcion,
       p.unidad_medida,
       p.precio_unitario,
       p.stock_minimo,
       p.maneja_lotes,
       p.requiere_vencimiento,
       1
FROM @productos p
JOIN dbo.Categorias c ON c.nombre = p.categoria AND c.activo = 1
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Productos x WHERE x.codigo = p.codigo
);

IF EXISTS (
    SELECT 1
    FROM @productos p
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Productos x WHERE x.codigo = p.codigo
    )
)
    THROW 51902, N'No se pudieron crear todos los productos de demostración. Verifique que las categorías existan y estén activas.', 1;

-- ============================================================================
-- 3. Entradas de inventario (crean los lotes)
-- ============================================================================

DECLARE @entradas TABLE
(
    codigo            NVARCHAR(30)  NOT NULL,
    cantidad          INT           NOT NULL,
    motivo            NVARCHAR(200) NOT NULL,
    numero_lote       NVARCHAR(50)  NULL,
    fecha_vencimiento DATE          NULL,
    dias              INT           NOT NULL
);

INSERT @entradas (codigo, cantidad, motivo, numero_lote, fecha_vencimiento, dias)
VALUES
    (N'MED-PAR-500', 1800, N'Compra inicial · lote PAR-2601', N'PAR-2601', DATEADD(day, 420, CONVERT(date, GETDATE())), -150),
    (N'MED-PAR-500',  400, N'Compra inicial · lote PAR-2512', N'PAR-2512', DATEADD(day,  25, CONVERT(date, GETDATE())),  -95),
    (N'MED-IBU-400', 1200, N'Compra inicial · lote IBU-2602', N'IBU-2602', DATEADD(day, 540, CONVERT(date, GETDATE())), -145),
    (N'MED-AMO-500',  300, N'Compra inicial · lote AMO-2601', N'AMO-2601', DATEADD(day, 300, CONVERT(date, GETDATE())), -140),
    (N'MED-OME-20',   800, N'Compra inicial · lote OME-2602', N'OME-2602', DATEADD(day, 480, CONVERT(date, GETDATE())), -135),
    (N'MED-SSF-09',   300, N'Compra inicial · lote SSF-2511', N'SSF-2511', DATEADD(day,  60, CONVERT(date, GETDATE())), -160),
    (N'MED-SSF-09',   200, N'Compra inicial · lote SSF-2604', N'SSF-2604', DATEADD(day, 240, CONVERT(date, GETDATE())), -120),
    (N'MED-DEX-05',   250, N'Compra inicial · lote DEX-2603', N'DEX-2603', DATEADD(day, 270, CONVERT(date, GETDATE())), -130),
    (N'MED-ADR-01',    40, N'Compra inicial · lote ADR-2601', N'ADR-2601', DATEADD(day, 330, CONVERT(date, GETDATE())), -125),
    (N'MAT-GUA-NIT-M', 80, N'Compra inicial · lote GUA-2602', N'GUA-2602', DATEADD(day, 720, CONVERT(date, GETDATE())), -120),
    (N'MAT-JER-10',  1200, N'Compra inicial · lote JER-2601', N'JER-2601', NULL, -115),
    (N'MAT-GAS-10',   400, N'Compra inicial · lote GAS-2601', N'GAS-2601', DATEADD(day,  20, CONVERT(date, GETDATE())), -110),
    (N'MAT-AGU-21',  2000, N'Compra inicial · lote AGU-2602', N'AGU-2602', NULL, -105),
    (N'MAT-CAT-20',   500, N'Compra inicial · lote CAT-2601', N'CAT-2601', NULL, -100),
    (N'MAT-SUT-30',   120, N'Compra inicial · lote SUT-2601', N'SUT-2601', DATEADD(day, 600, CONVERT(date, GETDATE())),  -95),
    (N'LAB-TUB-EDTA',1000, N'Compra inicial · lote EDTA-2602', N'EDTA-2602', DATEADD(day, 210, CONVERT(date, GETDATE())), -90),
    (N'LAB-TUB-SER', 1000, N'Compra inicial · lote SER-2602', N'SER-2602', DATEADD(day, 210, CONVERT(date, GETDATE())), -85),
    (N'LAB-REA-GLU',   10, N'Compra inicial · lote GLU-2601', N'GLU-2601', DATEADD(day, 150, CONVERT(date, GETDATE())), -80),
    (N'LAB-PAP-FIL',   30, N'Compra inicial · papel filtro', NULL, NULL, -75),
    (N'LIM-HIP-05',   120, N'Compra inicial · hipoclorito', NULL, NULL, -70),
    (N'LIM-ALC-70',   120, N'Compra inicial · alcohol 70%', NULL, NULL, -65),
    (N'EQP-TEN-DIG',    6, N'Compra inicial · tensiómetros', NULL, NULL, -60),
    (N'EQP-TER-INF',    8, N'Compra inicial · termómetros', NULL, NULL, -55);

DECLARE cur_entradas CURSOR LOCAL FAST_FORWARD FOR
    SELECT p.id_producto, e.cantidad, e.motivo, e.numero_lote,
           e.fecha_vencimiento, e.dias
    FROM @entradas e
    JOIN dbo.Productos p ON p.codigo = e.codigo
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Movimientos m
        WHERE m.id_producto = p.id_producto
          AND m.tipo_movimiento = 'ENTRADA'
          AND m.motivo = e.motivo
    )
    ORDER BY e.dias ASC, e.codigo ASC;

OPEN cur_entradas;

FETCH NEXT FROM cur_entradas
    INTO @id_producto, @cantidad, @motivo, @numero_lote, @vence, @dias;

WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @res;

    INSERT @res (id_movimiento, id_lote, stock_anterior, stock_posterior)
    EXEC dbo.sp_Movimientos_RegistrarEntrada
        @id_producto, @id_admin, @cantidad, @motivo, @numero_lote, @vence;

    SELECT @id_movimiento = id_movimiento, @id_lote = id_lote FROM @res;

    -- Reparte el historial en los últimos cuatro meses.
    UPDATE dbo.Movimientos
    SET fecha_movimiento = DATEADD(day, @dias, SYSDATETIME())
    WHERE id_movimiento = @id_movimiento;

    UPDATE dbo.Lotes
    SET fecha_registro = DATEADD(day, @dias, SYSDATETIME())
    WHERE id_lote = @id_lote;

    FETCH NEXT FROM cur_entradas
        INTO @id_producto, @cantidad, @motivo, @numero_lote, @vence, @dias;
END;

CLOSE cur_entradas;
DEALLOCATE cur_entradas;

-- ============================================================================
-- 4. Salidas de inventario (consumo por área)
-- ============================================================================

DECLARE @salidas TABLE
(
    codigo      NVARCHAR(30)  NOT NULL,
    numero_lote NVARCHAR(50)  NULL,
    area        NVARCHAR(100) NOT NULL,
    cantidad    INT           NOT NULL,
    motivo      NVARCHAR(200) NOT NULL,
    dias        INT           NOT NULL,
    email       NVARCHAR(150) NOT NULL
);

INSERT @salidas (codigo, numero_lote, area, cantidad, motivo, dias, email)
VALUES
    (N'MED-PAR-500', N'PAR-2601', N'Emergencia', 350,
     N'Consumo en Emergencia · paracetamol', -60, N'admin.desarrollo@sigih.test'),
    (N'MED-PAR-500', N'PAR-2601', N'Hospitalización', 250,
     N'Consumo en Hospitalización · paracetamol', -20, N'almacen.demo@sigih.test'),
    (N'MED-IBU-400', N'IBU-2602', N'Consultorios externos', 300,
     N'Dispensación en Consultorios externos · ibuprofeno', -50, N'admin.desarrollo@sigih.test'),
    (N'MED-AMO-500', N'AMO-2601', N'Emergencia', 50,
     N'Tratamiento en Emergencia · amoxicilina', -45, N'admin.desarrollo@sigih.test'),
    (N'MED-OME-20', N'OME-2602', N'Hospitalización', 180,
     N'Tratamiento en Hospitalización · omeprazol', -40, N'admin.desarrollo@sigih.test'),
    (N'MED-SSF-09', N'SSF-2511', N'Emergencia', 280,
     N'Reposición en Emergencia · solución fisiológica', -100, N'admin.desarrollo@sigih.test'),
    (N'MED-DEX-05', N'DEX-2603', N'UCI', 60,
     N'Infusión en UCI · dextrosa', -35, N'admin.desarrollo@sigih.test'),
    (N'MAT-GUA-NIT-M', N'GUA-2602', N'Quirófano', 20,
     N'Consumo en Quirófano · guantes', -30, N'almacen.demo@sigih.test'),
    (N'MAT-JER-10', N'JER-2601', N'Emergencia', 350,
     N'Consumo en Emergencia · jeringas', -25, N'admin.desarrollo@sigih.test'),
    (N'MAT-GAS-10', N'GAS-2601', N'Quirófano', 80,
     N'Curaciones en Quirófano · gasas', -22, N'almacen.demo@sigih.test'),
    (N'MAT-AGU-21', N'AGU-2602', N'Laboratorio', 600,
     N'Toma de muestras · agujas', -20, N'admin.desarrollo@sigih.test'),
    (N'MAT-CAT-20', N'CAT-2601', N'UCI', 120,
     N'Canalización en UCI · catéteres', -18, N'admin.desarrollo@sigih.test'),
    (N'MAT-SUT-30', N'SUT-2601', N'Quirófano', 30,
     N'Suturas en Quirófano', -16, N'almacen.demo@sigih.test'),
    (N'LAB-TUB-EDTA', N'EDTA-2602', N'Laboratorio', 250,
     N'Hemogramas · tubos EDTA', -14, N'admin.desarrollo@sigih.test'),
    (N'LAB-TUB-SER', N'SER-2602', N'Laboratorio', 240,
     N'Química sanguínea · tubos secos', -12, N'admin.desarrollo@sigih.test'),
    (N'LAB-PAP-FIL', NULL, N'Laboratorio', 8,
     N'Filtración de muestras · papel filtro', -10, N'admin.desarrollo@sigih.test'),
    (N'LIM-HIP-05', NULL, N'Hospitalización', 35,
     N'Desinfección en Hospitalización · hipoclorito', -8, N'almacen.demo@sigih.test'),
    (N'LIM-ALC-70', NULL, N'Quirófano', 40,
     N'Asepsia en Quirófano · alcohol', -6, N'almacen.demo@sigih.test'),
    (N'EQP-TEN-DIG', NULL, N'Consultorios externos', 2,
     N'Asignación en Consultorios externos · tensiómetro', -5, N'admin.desarrollo@sigih.test'),
    (N'EQP-TER-INF', NULL, N'Pediatría', 3,
     N'Asignación en Pediatría · termómetro', -3, N'almacen.demo@sigih.test');

DECLARE cur_salidas CURSOR LOCAL FAST_FORWARD FOR
    SELECT p.id_producto,
           l.id_lote,
           a.id_area,
           s.cantidad,
           s.motivo,
           s.dias,
           COALESCE(u.id_usuario, @id_admin)
    FROM @salidas s
    JOIN dbo.Productos p ON p.codigo = s.codigo
    JOIN dbo.Lotes l ON l.id_producto = p.id_producto
        AND (
            (s.numero_lote IS NULL AND l.numero_lote IS NULL)
            OR l.numero_lote = s.numero_lote
        )
    JOIN dbo.AreasHospitalarias a ON a.nombre = s.area AND a.activo = 1
    LEFT JOIN dbo.Usuarios u ON u.email = s.email AND u.activo = 1
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.Movimientos m
        WHERE m.id_producto = p.id_producto
          AND m.tipo_movimiento = 'SALIDA'
          AND m.motivo = s.motivo
    )
    ORDER BY s.dias ASC, s.codigo ASC;

OPEN cur_salidas;

FETCH NEXT FROM cur_salidas
    INTO @id_producto, @id_lote, @id_area, @cantidad, @motivo, @dias, @id_usuario;

WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @res;

    INSERT @res (id_movimiento, stock_anterior, stock_posterior)
    EXEC dbo.sp_Movimientos_RegistrarSalida
        @id_producto, @id_lote, @id_usuario, @id_area, @cantidad, @motivo;

    SELECT @id_movimiento = id_movimiento FROM @res;

    UPDATE dbo.Movimientos
    SET fecha_movimiento = DATEADD(day, @dias, SYSDATETIME())
    WHERE id_movimiento = @id_movimiento;

    FETCH NEXT FROM cur_salidas
        INTO @id_producto, @id_lote, @id_area, @cantidad, @motivo, @dias, @id_usuario;
END;

CLOSE cur_salidas;
DEALLOCATE cur_salidas;

-- ============================================================================
-- 5. Lote vencido de demostración
-- ----------------------------------------------------------------------------
-- El SP no permite ingresar lotes vencidos, así que SSF-2511 se creó con
-- vencimiento futuro y aquí se retrocede para simular un lote ya vencido.
-- Se ejecuta después de las salidas para que estas sigan siendo válidas.
-- ============================================================================

UPDATE dbo.Lotes
SET fecha_vencimiento = DATEADD(day, -12, CONVERT(date, GETDATE()))
WHERE numero_lote = N'SSF-2511'
  AND id_producto = (
      SELECT id_producto FROM dbo.Productos WHERE codigo = N'MED-SSF-09'
  );

-- ============================================================================
-- 6. Resumen
-- ============================================================================

PRINT N'18_seed_demo.sql ejecutado.';

SELECT
    (SELECT COUNT(*)
     FROM dbo.Productos p
     JOIN @productos x ON x.codigo = p.codigo) AS productos_demo,
    (SELECT COUNT(*)
     FROM dbo.Lotes l
     JOIN dbo.Productos p ON p.id_producto = l.id_producto
     JOIN @productos x ON x.codigo = p.codigo) AS lotes_demo,
    (SELECT COUNT(*)
     FROM dbo.Movimientos m
     JOIN dbo.Productos p ON p.id_producto = m.id_producto
     JOIN @productos x ON x.codigo = p.codigo) AS movimientos_demo;
GO
