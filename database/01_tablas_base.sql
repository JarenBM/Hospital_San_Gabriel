-- SIGIH | 01 - Tablas base del esquema existente
-- Idempotente: solo crea lo que no existe. No altera tablas ya creadas.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuarios
    (
        id_usuario    INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Usuarios PRIMARY KEY,
        nombre        NVARCHAR(100) NOT NULL,
        email         NVARCHAR(150) NOT NULL
            CONSTRAINT UQ_Usuarios_Email UNIQUE,
        password_hash NVARCHAR(255) NOT NULL,
        activo        BIT NOT NULL
            CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
        fecha_creacion DATETIME2 NOT NULL
            CONSTRAINT DF_Usuarios_Fecha DEFAULT (SYSDATETIME())
    );
END;
GO

IF OBJECT_ID(N'dbo.Categorias', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Categorias
    (
        id_categoria INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Categorias PRIMARY KEY,
        nombre       NVARCHAR(100) NOT NULL
            CONSTRAINT UQ_Categorias_Nombre UNIQUE,
        descripcion  NVARCHAR(255) NULL,
        activo       BIT NOT NULL
            CONSTRAINT DF_Categorias_Activo DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Productos
    (
        id_producto         INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Productos PRIMARY KEY,
        id_categoria        INT NOT NULL
            CONSTRAINT FK_Productos_Categorias REFERENCES dbo.Categorias(id_categoria),
        codigo              NVARCHAR(30) NOT NULL
            CONSTRAINT UQ_Productos_Codigo UNIQUE,
        nombre              NVARCHAR(150) NOT NULL,
        descripcion         NVARCHAR(500) NULL,
        unidad_medida       NVARCHAR(30) NOT NULL,
        precio_unitario     DECIMAL(12,2) NOT NULL
            CONSTRAINT CK_Productos_Precio CHECK (precio_unitario > 0),
        stock_minimo        INT NOT NULL
            CONSTRAINT DF_Productos_StockMinimo DEFAULT (0)
            CONSTRAINT CK_Productos_StockMinimo CHECK (stock_minimo >= 0),
        maneja_lotes        BIT NOT NULL
            CONSTRAINT DF_Productos_ManejaLotes DEFAULT (0),
        requiere_vencimiento BIT NOT NULL
            CONSTRAINT DF_Productos_RequiereVencimiento DEFAULT (0),
        activo              BIT NOT NULL
            CONSTRAINT DF_Productos_Activo DEFAULT (1),
        CONSTRAINT CK_Producto_Vence CHECK (requiere_vencimiento = 0 OR maneja_lotes = 1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Lotes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Lotes
    (
        id_lote           INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Lotes PRIMARY KEY,
        id_producto       INT NOT NULL
            CONSTRAINT FK_Lotes_Productos REFERENCES dbo.Productos(id_producto),
        numero_lote       NVARCHAR(50) NULL,
        fecha_vencimiento DATE NULL,
        stock_actual      INT NOT NULL
            CONSTRAINT DF_Lotes_Stock DEFAULT (0)
            CONSTRAINT CK_Lotes_Stock CHECK (stock_actual >= 0),
        fecha_registro    DATETIME2 NOT NULL
            CONSTRAINT DF_Lotes_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_LoteProducto UNIQUE (id_producto, id_lote)
    );
END;
GO

IF OBJECT_ID(N'dbo.AreasHospitalarias', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AreasHospitalarias
    (
        id_area INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_AreasHospitalarias PRIMARY KEY,
        nombre  NVARCHAR(100) NOT NULL
            CONSTRAINT UQ_AreasHospitalarias_Nombre UNIQUE,
        activo  BIT NOT NULL
            CONSTRAINT DF_AreasHospitalarias_Activo DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Movimientos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Movimientos
    (
        id_movimiento    INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Movimientos PRIMARY KEY,
        id_producto      INT NOT NULL
            CONSTRAINT FK_Movimientos_Productos REFERENCES dbo.Productos(id_producto),
        id_lote          INT NOT NULL,
        id_usuario       INT NOT NULL
            CONSTRAINT FK_Movimientos_Usuarios REFERENCES dbo.Usuarios(id_usuario),
        id_area          INT NULL
            CONSTRAINT FK_Movimientos_Areas REFERENCES dbo.AreasHospitalarias(id_area),
        tipo_movimiento  VARCHAR(10) NOT NULL
            CONSTRAINT CK_Movimientos_Tipo CHECK (tipo_movimiento IN ('ENTRADA','SALIDA')),
        cantidad         INT NOT NULL
            CONSTRAINT CK_Movimientos_Cantidad CHECK (cantidad > 0),
        fecha_movimiento DATETIME2 NOT NULL
            CONSTRAINT DF_Movimientos_Fecha DEFAULT (SYSDATETIME()),
        motivo           NVARCHAR(200) NOT NULL,
        stock_anterior   INT NOT NULL
            CONSTRAINT CK_Movimientos_StockAnterior CHECK (stock_anterior >= 0),
        stock_posterior  INT NOT NULL
            CONSTRAINT CK_Movimientos_StockPosterior CHECK (stock_posterior >= 0),
        CONSTRAINT FK_Mov_LoteProducto
            FOREIGN KEY (id_producto, id_lote) REFERENCES dbo.Lotes(id_producto, id_lote),
        CONSTRAINT CK_Mov_Area CHECK (
            (tipo_movimiento = 'ENTRADA' AND id_area IS NULL)
            OR (tipo_movimiento = 'SALIDA' AND id_area IS NOT NULL)
        ),
        CONSTRAINT CK_Mov_Cambio CHECK (
            (tipo_movimiento = 'ENTRADA' AND stock_posterior = stock_anterior + cantidad)
            OR (tipo_movimiento = 'SALIDA' AND stock_anterior = stock_posterior + cantidad)
        )
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Lote_Numero' AND object_id = OBJECT_ID(N'dbo.Lotes'))
BEGIN
    CREATE UNIQUE INDEX UX_Lote_Numero
        ON dbo.Lotes(id_producto, numero_lote)
        WHERE numero_lote IS NOT NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Lote_SinNumero' AND object_id = OBJECT_ID(N'dbo.Lotes'))
BEGIN
    CREATE UNIQUE INDEX UX_Lote_SinNumero
        ON dbo.Lotes(id_producto)
        WHERE numero_lote IS NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Productos_Categoria' AND object_id = OBJECT_ID(N'dbo.Productos'))
    CREATE INDEX IX_Productos_Categoria ON dbo.Productos(id_categoria);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Lotes_Vencimiento' AND object_id = OBJECT_ID(N'dbo.Lotes'))
    CREATE INDEX IX_Lotes_Vencimiento ON dbo.Lotes(fecha_vencimiento, id_producto) INCLUDE(stock_actual);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Producto_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Producto_Fecha ON dbo.Movimientos(id_producto, fecha_movimiento DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Tipo_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Tipo_Fecha ON dbo.Movimientos(tipo_movimiento, fecha_movimiento DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Area_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Area_Fecha ON dbo.Movimientos(id_area, fecha_movimiento DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Mov_Usuario_Fecha' AND object_id = OBJECT_ID(N'dbo.Movimientos'))
    CREATE INDEX IX_Mov_Usuario_Fecha ON dbo.Movimientos(id_usuario, fecha_movimiento DESC);
GO

PRINT N'01_tablas_base.sql ejecutado.';
GO
