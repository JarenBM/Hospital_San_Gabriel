-- SIGIH | 08 - Stored procedures de Movimientos
-- Convención: sp_Movimientos_<Accion>
-- Las transacciones de stock viven aquí: BEGIN TRAN + XACT_ABORT + ROLLBACK.
-- Códigos: 511xx entradas, 512xx salidas.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_RegistrarEntrada
    @id_producto        INT,
    @id_usuario         INT,
    @cantidad           INT,
    @motivo             NVARCHAR(200),
    @numero_lote        NVARCHAR(50) = NULL,
    @fecha_vencimiento  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maneja BIT,
            @requiere BIT,
            @id_lote INT,
            @prev INT,
            @nuevo INT,
            @fecha_existente DATE,
            @numero_existente NVARCHAR(50);

    BEGIN TRY
        BEGIN TRAN;

        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 51101, N'Cantidad inválida', 1;

        IF NULLIF(TRIM(@motivo), N'') IS NULL
            THROW 51102, N'Motivo obligatorio', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Usuarios
            WHERE id_usuario = @id_usuario AND activo = 1
        )
            THROW 51103, N'Usuario inválido o inactivo', 1;

        SELECT @maneja = maneja_lotes,
               @requiere = requiere_vencimiento
        FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK)
        WHERE id_producto = @id_producto AND activo = 1;

        IF @maneja IS NULL
            THROW 51104, N'Producto inválido o inactivo', 1;

        SET @numero_lote = NULLIF(TRIM(@numero_lote), N'');

        IF @maneja = 1 AND @numero_lote IS NULL
            THROW 51105, N'Número de lote obligatorio', 1;

        IF @maneja = 0 AND (@numero_lote IS NOT NULL OR @fecha_vencimiento IS NOT NULL)
            THROW 51106, N'El producto no maneja lotes', 1;

        IF @requiere = 1 AND @fecha_vencimiento IS NULL
            THROW 51107, N'Fecha de vencimiento obligatoria', 1;

        IF @fecha_vencimiento IS NOT NULL
           AND @fecha_vencimiento < CONVERT(date, GETDATE())
            THROW 51108, N'No se admite el ingreso de un lote vencido', 1;

        SELECT @prev = COALESCE(SUM(stock_actual), 0)
        FROM dbo.Lotes
        WHERE id_producto = @id_producto;

        SELECT @id_lote = id_lote,
               @fecha_existente = fecha_vencimiento,
               @numero_existente = numero_lote
        FROM dbo.Lotes WITH (UPDLOCK, HOLDLOCK)
        WHERE id_producto = @id_producto
          AND (
                (@numero_lote IS NULL AND numero_lote IS NULL)
                OR numero_lote = @numero_lote
              );

        IF @id_lote IS NOT NULL
        BEGIN
            IF (@fecha_existente <> @fecha_vencimiento)
               OR (@fecha_existente IS NULL AND @fecha_vencimiento IS NOT NULL)
               OR (@fecha_existente IS NOT NULL AND @fecha_vencimiento IS NULL)
                THROW 51109, N'El vencimiento no coincide con el lote existente', 1;

            UPDATE dbo.Lotes
            SET stock_actual = stock_actual + @cantidad
            WHERE id_lote = @id_lote;
        END
        ELSE
        BEGIN
            INSERT dbo.Lotes (id_producto, numero_lote, fecha_vencimiento, stock_actual)
            VALUES (@id_producto, @numero_lote, @fecha_vencimiento, @cantidad);

            SET @id_lote = CAST(SCOPE_IDENTITY() AS INT);
        END;

        SET @nuevo = @prev + @cantidad;

        INSERT dbo.Movimientos
        (
            id_producto, id_lote, id_usuario, id_area, tipo_movimiento,
            cantidad, motivo, stock_anterior, stock_posterior
        )
        VALUES
        (
            @id_producto, @id_lote, @id_usuario, NULL, 'ENTRADA',
            @cantidad, @motivo, @prev, @nuevo
        );

        DECLARE @id_movimiento INT = CAST(SCOPE_IDENTITY() AS INT);

        -- Auditoría dentro de la misma transacción: si el movimiento se
        -- confirma, su rastro también; si se revierte, no queda registro.
        INSERT dbo.Auditoria
        (
            id_usuario, accion, modulo, id_registro, detalle
        )
        VALUES
        (
            @id_usuario,
            N'ENTRADA',
            N'movimientos',
            CAST(@id_movimiento AS NVARCHAR(50)),
            LEFT(CONCAT(
                N'Producto: ', @id_producto,
                N', lote: ', COALESCE(@numero_lote, N'sin lote'),
                N', cantidad: ', @cantidad
            ), 500)
        );

        COMMIT;

        SELECT @id_movimiento AS id_movimiento,
               @id_lote AS id_lote,
               @prev AS stock_anterior,
               @nuevo AS stock_posterior;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_RegistrarSalida
    @id_producto INT,
    @id_usuario  INT,
    @id_area     INT,
    @cantidad    INT,
    @motivo      NVARCHAR(200),
    @id_lote     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @requiere BIT,
            @stock_lote INT,
            @vence DATE,
            @numero_lote NVARCHAR(50),
            @prev INT,
            @nuevo INT;

    BEGIN TRY
        BEGIN TRAN;

        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 51201, N'Cantidad inválida', 1;

        IF NULLIF(TRIM(@motivo), N'') IS NULL
            THROW 51202, N'Motivo obligatorio', 1;

        SELECT @requiere = requiere_vencimiento
        FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK)
        WHERE id_producto = @id_producto AND activo = 1;

        IF @requiere IS NULL
            THROW 51203, N'Producto inválido o inactivo', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Usuarios
            WHERE id_usuario = @id_usuario AND activo = 1
        )
            THROW 51204, N'Usuario inválido o inactivo', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.AreasHospitalarias
            WHERE id_area = @id_area AND activo = 1
        )
            THROW 51205, N'Área inválida o inactiva', 1;

        IF @id_lote IS NULL
        BEGIN
            -- FEFO: lote vigente con el vencimiento más próximo que cubra
            -- la cantidad pedida. Los lotes sin vencimiento quedan al final.
            SELECT TOP (1)
                   @id_lote     = l.id_lote,
                   @stock_lote  = l.stock_actual,
                   @vence       = l.fecha_vencimiento,
                   @numero_lote = l.numero_lote
            FROM dbo.Lotes l WITH (UPDLOCK, HOLDLOCK)
            WHERE l.id_producto = @id_producto
              AND l.stock_actual >= @cantidad
              AND (
                    l.fecha_vencimiento IS NULL
                    OR l.fecha_vencimiento > CONVERT(date, GETDATE())
                  )
            ORDER BY CASE WHEN l.fecha_vencimiento IS NULL THEN 1 ELSE 0 END,
                     l.fecha_vencimiento,
                     l.id_lote;

            IF @id_lote IS NULL
                THROW 51209, N'No hay lotes vigentes con stock suficiente para la cantidad solicitada', 1;
        END
        ELSE
        BEGIN
            SELECT @stock_lote  = stock_actual,
                   @vence       = fecha_vencimiento,
                   @numero_lote = numero_lote
            FROM dbo.Lotes WITH (UPDLOCK, HOLDLOCK)
            WHERE id_lote = @id_lote AND id_producto = @id_producto;

            IF @stock_lote IS NULL
                THROW 51206, N'Lote no encontrado', 1;
        END;

        IF @requiere = 1 AND @vence IS NULL
            THROW 51207, N'El lote no tiene fecha de vencimiento', 1;

        -- Un lote con vencimiento hoy ya no es despachable.
        IF @vence <= CONVERT(date, GETDATE())
            THROW 51208, N'El lote está vencido', 1;

        IF @stock_lote < @cantidad
            THROW 51209, N'Stock insuficiente en el lote', 1;

        SELECT @prev = COALESCE(SUM(stock_actual), 0)
        FROM dbo.Lotes
        WHERE id_producto = @id_producto;

        UPDATE dbo.Lotes
        SET stock_actual = stock_actual - @cantidad
        WHERE id_lote = @id_lote
          AND stock_actual >= @cantidad;

        IF @@ROWCOUNT <> 1
            THROW 51210, N'El stock cambió durante la operación', 1;

        SET @nuevo = @prev - @cantidad;

        INSERT dbo.Movimientos
        (
            id_producto, id_lote, id_usuario, id_area, tipo_movimiento,
            cantidad, motivo, stock_anterior, stock_posterior
        )
        VALUES
        (
            @id_producto, @id_lote, @id_usuario, @id_area, 'SALIDA',
            @cantidad, @motivo, @prev, @nuevo
        );

        DECLARE @id_movimiento INT = CAST(SCOPE_IDENTITY() AS INT);

        -- Auditoría dentro de la misma transacción: si el movimiento se
        -- confirma, su rastro también; si se revierte, no queda registro.
        INSERT dbo.Auditoria
        (
            id_usuario, accion, modulo, id_registro, id_area, detalle
        )
        VALUES
        (
            @id_usuario,
            N'SALIDA',
            N'movimientos',
            CAST(@id_movimiento AS NVARCHAR(50)),
            @id_area,
            LEFT(CONCAT(
                N'Producto: ', @id_producto,
                N', área: ', @id_area,
                N', lote: ', COALESCE(@numero_lote, N'sin lote'),
                N', cantidad: ', @cantidad
            ), 500)
        );

        COMMIT;

        SELECT @id_movimiento AS id_movimiento,
               @id_lote AS id_lote,
               @numero_lote AS numero_lote,
               @prev AS stock_anterior,
               @nuevo AS stock_posterior;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_Listar
    @id_producto     INT = NULL,
    @tipo_movimiento VARCHAR(10) = NULL,
    @id_area         INT = NULL,
    @desde           DATE = NULL,
    @hasta           DATE = NULL,
    @busqueda        NVARCHAR(150) = NULL,
    @pagina          INT = NULL,
    @tamano          INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @offset INT = 0,
            @fetch  INT = 2147483647;

    IF @pagina IS NOT NULL OR @tamano IS NOT NULL
    BEGIN
        SET @pagina = ISNULL(@pagina, 1);
        SET @tamano = ISNULL(@tamano, 25);

        IF @pagina < 1 SET @pagina = 1;
        IF @tamano < 1 SET @tamano = 25;

        SET @offset = (@pagina - 1) * @tamano;
        SET @fetch  = @tamano;
    END

    SELECT m.id_movimiento,
           m.fecha_movimiento,
           m.tipo_movimiento,
           p.codigo,
           p.nombre AS producto,
           l.numero_lote,
           l.fecha_vencimiento,
           a.nombre AS area,
           u.nombre AS usuario,
           m.cantidad,
           m.motivo,
           m.stock_anterior,
           m.stock_posterior,
           COUNT(*) OVER () AS total
    FROM dbo.Movimientos m
    JOIN dbo.Productos p ON p.id_producto = m.id_producto
    JOIN dbo.Lotes l ON l.id_lote = m.id_lote
    JOIN dbo.Usuarios u ON u.id_usuario = m.id_usuario
    LEFT JOIN dbo.AreasHospitalarias a ON a.id_area = m.id_area
    WHERE (@id_producto IS NULL OR m.id_producto = @id_producto)
      AND (@tipo_movimiento IS NULL OR m.tipo_movimiento = @tipo_movimiento)
      AND (@id_area IS NULL OR m.id_area = @id_area)
      AND (@desde IS NULL OR m.fecha_movimiento >= @desde)
      AND (@hasta IS NULL
           OR m.fecha_movimiento < DATEADD(day, 1, CAST(@hasta AS DATETIME2)))
      AND (@busqueda IS NULL
           OR p.codigo LIKE N'%' + @busqueda + N'%'
           OR p.nombre LIKE N'%' + @busqueda + N'%'
           OR l.numero_lote LIKE N'%' + @busqueda + N'%'
           OR m.motivo LIKE N'%' + @busqueda + N'%'
           OR u.nombre LIKE N'%' + @busqueda + N'%')
    ORDER BY m.fecha_movimiento DESC, m.id_movimiento DESC
    OFFSET @offset ROWS FETCH NEXT @fetch ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Movimientos_Obtener
    @id_movimiento INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.id_movimiento,
           m.fecha_movimiento,
           m.tipo_movimiento,
           p.codigo,
           p.nombre AS producto,
           l.numero_lote,
           l.fecha_vencimiento,
           a.nombre AS area,
           u.nombre AS usuario,
           m.cantidad,
           m.motivo,
           m.stock_anterior,
           m.stock_posterior
    FROM dbo.Movimientos m
    JOIN dbo.Productos p ON p.id_producto = m.id_producto
    JOIN dbo.Lotes l ON l.id_lote = m.id_lote
    JOIN dbo.Usuarios u ON u.id_usuario = m.id_usuario
    LEFT JOIN dbo.AreasHospitalarias a ON a.id_area = m.id_area
    WHERE m.id_movimiento = @id_movimiento;
END;
GO

PRINT N'08_sp_movimientos.sql ejecutado.';
GO
