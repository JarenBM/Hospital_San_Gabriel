-- SIGIH | SQL Server 2017+ | ejecutar en SSMS en orden
-- Base nueva; no ejecutar sobre una base SIGIH existente sin respaldo.
IF DB_ID(N'SIGIH') IS NULL EXEC(N'CREATE DATABASE SIGIH');
GO
USE SIGIH;
GO
CREATE TABLE dbo.Usuarios(id_usuario INT IDENTITY PRIMARY KEY,nombre NVARCHAR(100) NOT NULL,email NVARCHAR(150) NOT NULL UNIQUE,password_hash NVARCHAR(255) NOT NULL,activo BIT NOT NULL DEFAULT 1,fecha_creacion DATETIME2 NOT NULL DEFAULT SYSDATETIME());
CREATE TABLE dbo.Categorias(id_categoria INT IDENTITY PRIMARY KEY,nombre NVARCHAR(100) NOT NULL UNIQUE,descripcion NVARCHAR(255),activo BIT NOT NULL DEFAULT 1);
CREATE TABLE dbo.Productos(id_producto INT IDENTITY PRIMARY KEY,id_categoria INT NOT NULL REFERENCES dbo.Categorias(id_categoria),codigo NVARCHAR(30) NOT NULL UNIQUE,nombre NVARCHAR(150) NOT NULL,descripcion NVARCHAR(500),unidad_medida NVARCHAR(30) NOT NULL,precio_unitario DECIMAL(12,2) NOT NULL CHECK(precio_unitario>0),stock_minimo INT NOT NULL DEFAULT 0 CHECK(stock_minimo>=0),maneja_lotes BIT NOT NULL DEFAULT 0,requiere_vencimiento BIT NOT NULL DEFAULT 0,activo BIT NOT NULL DEFAULT 1,CONSTRAINT CK_Producto_Vence CHECK(requiere_vencimiento=0 OR maneja_lotes=1));
CREATE TABLE dbo.Lotes(id_lote INT IDENTITY PRIMARY KEY,id_producto INT NOT NULL REFERENCES dbo.Productos(id_producto),numero_lote NVARCHAR(50),fecha_vencimiento DATE,stock_actual INT NOT NULL DEFAULT 0 CHECK(stock_actual>=0),fecha_registro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),CONSTRAINT UQ_LoteProducto UNIQUE(id_producto,id_lote));
CREATE UNIQUE INDEX UX_Lote_Numero ON dbo.Lotes(id_producto,numero_lote) WHERE numero_lote IS NOT NULL;
CREATE UNIQUE INDEX UX_Lote_SinNumero ON dbo.Lotes(id_producto) WHERE numero_lote IS NULL;
CREATE TABLE dbo.AreasHospitalarias(id_area INT IDENTITY PRIMARY KEY,nombre NVARCHAR(100) NOT NULL UNIQUE,activo BIT NOT NULL DEFAULT 1);
CREATE TABLE dbo.Movimientos(id_movimiento INT IDENTITY PRIMARY KEY,id_producto INT NOT NULL REFERENCES dbo.Productos(id_producto),id_lote INT NOT NULL,id_usuario INT NOT NULL REFERENCES dbo.Usuarios(id_usuario),id_area INT NULL REFERENCES dbo.AreasHospitalarias(id_area),tipo_movimiento VARCHAR(10) NOT NULL CHECK(tipo_movimiento IN('ENTRADA','SALIDA')),cantidad INT NOT NULL CHECK(cantidad>0),fecha_movimiento DATETIME2 NOT NULL DEFAULT SYSDATETIME(),motivo NVARCHAR(200) NOT NULL,stock_anterior INT NOT NULL CHECK(stock_anterior>=0),stock_posterior INT NOT NULL CHECK(stock_posterior>=0),CONSTRAINT FK_Mov_LoteProducto FOREIGN KEY(id_producto,id_lote) REFERENCES dbo.Lotes(id_producto,id_lote),CONSTRAINT CK_Mov_Area CHECK((tipo_movimiento='ENTRADA' AND id_area IS NULL) OR (tipo_movimiento='SALIDA' AND id_area IS NOT NULL)),CONSTRAINT CK_Mov_Cambio CHECK((tipo_movimiento='ENTRADA' AND stock_posterior=stock_anterior+cantidad) OR (tipo_movimiento='SALIDA' AND stock_anterior=stock_posterior+cantidad)));
CREATE INDEX IX_Productos_Categoria ON dbo.Productos(id_categoria);
CREATE INDEX IX_Lotes_Vencimiento ON dbo.Lotes(fecha_vencimiento,id_producto) INCLUDE(stock_actual);
CREATE INDEX IX_Mov_Producto_Fecha ON dbo.Movimientos(id_producto,fecha_movimiento DESC);
CREATE INDEX IX_Mov_Tipo_Fecha ON dbo.Movimientos(tipo_movimiento,fecha_movimiento DESC);
CREATE INDEX IX_Mov_Area_Fecha ON dbo.Movimientos(id_area,fecha_movimiento DESC);
GO
-- Categorías y áreas de la consigna
INSERT INTO dbo.Categorias(nombre,descripcion) VALUES(N'Medicamentos',N'Medicamentos de uso hospitalario'),(N'Material médico',N'Insumos médicos'),(N'Material de laboratorio',N'Insumos de laboratorio'),(N'Limpieza hospitalaria',N'Productos de limpieza');
INSERT INTO dbo.AreasHospitalarias(nombre) VALUES(N'Emergencia'),(N'Hospitalización'),(N'Consultorios externos'),(N'Laboratorio');
GO
-- Usuarios: hash generado en backend con Argon2/bcrypt; nunca texto plano.
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_Crear @nombre NVARCHAR(100),@email NVARCHAR(150),@password_hash NVARCHAR(255)
AS BEGIN SET NOCOUNT ON; IF NULLIF(TRIM(@nombre),'') IS NULL OR NULLIF(TRIM(@email),'') IS NULL OR NULLIF(TRIM(@password_hash),'') IS NULL THROW 51001,'Datos de usuario incompletos',1; INSERT dbo.Usuarios(nombre,email,password_hash) VALUES(TRIM(@nombre),TRIM(@email),@password_hash); SELECT CAST(SCOPE_IDENTITY() AS INT) id_usuario; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_ObtenerPorEmail @email NVARCHAR(150)
AS BEGIN SET NOCOUNT ON; SELECT id_usuario,nombre,email,password_hash,activo FROM dbo.Usuarios WHERE email=@email; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Crear @nombre NVARCHAR(100),@descripcion NVARCHAR(255)=NULL
AS BEGIN SET NOCOUNT ON; IF NULLIF(TRIM(@nombre),'') IS NULL THROW 51002,'Nombre de categoría requerido',1; INSERT dbo.Categorias(nombre,descripcion) VALUES(TRIM(@nombre),@descripcion); SELECT CAST(SCOPE_IDENTITY() AS INT) id_categoria; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Listar
AS BEGIN SET NOCOUNT ON; SELECT id_categoria,nombre,descripcion,activo FROM dbo.Categorias ORDER BY nombre; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Producto_Crear @id_categoria INT,@codigo NVARCHAR(30),@nombre NVARCHAR(150),@descripcion NVARCHAR(500)=NULL,@unidad_medida NVARCHAR(30),@precio_unitario DECIMAL(12,2),@stock_minimo INT=0,@maneja_lotes BIT=0,@requiere_vencimiento BIT=0
AS BEGIN SET NOCOUNT ON; IF NOT EXISTS(SELECT 1 FROM dbo.Categorias WHERE id_categoria=@id_categoria AND activo=1) THROW 51003,'Categoría no válida',1; IF NULLIF(TRIM(@codigo),'') IS NULL OR NULLIF(TRIM(@nombre),'') IS NULL OR NULLIF(TRIM(@unidad_medida),'') IS NULL THROW 51004,'Campos obligatorios incompletos',1; INSERT dbo.Productos(id_categoria,codigo,nombre,descripcion,unidad_medida,precio_unitario,stock_minimo,maneja_lotes,requiere_vencimiento) VALUES(@id_categoria,TRIM(@codigo),TRIM(@nombre),@descripcion,TRIM(@unidad_medida),@precio_unitario,@stock_minimo,@maneja_lotes,@requiere_vencimiento); SELECT CAST(SCOPE_IDENTITY() AS INT) id_producto; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Producto_Listar @busqueda NVARCHAR(150)=NULL,@id_categoria INT=NULL,@solo_activos BIT=NULL
AS BEGIN SET NOCOUNT ON; SELECT p.id_producto,p.codigo,p.nombre,p.descripcion,p.id_categoria,c.nombre categoria,p.unidad_medida,p.precio_unitario,p.stock_minimo,p.maneja_lotes,p.requiere_vencimiento,p.activo,COALESCE(s.stock_total,0) stock_total,COALESCE(s.stock_disponible,0) stock_disponible FROM dbo.Productos p JOIN dbo.Categorias c ON c.id_categoria=p.id_categoria OUTER APPLY(SELECT SUM(l.stock_actual) stock_total,SUM(CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento>=CONVERT(date,GETDATE()) THEN l.stock_actual ELSE 0 END) stock_disponible FROM dbo.Lotes l WHERE l.id_producto=p.id_producto) s WHERE (@busqueda IS NULL OR p.codigo LIKE N'%'+@busqueda+N'%' OR p.nombre LIKE N'%'+@busqueda+N'%') AND (@id_categoria IS NULL OR p.id_categoria=@id_categoria) AND (@solo_activos IS NULL OR p.activo=@solo_activos) ORDER BY p.nombre; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Producto_Obtener @id_producto INT
AS BEGIN SET NOCOUNT ON; SELECT * FROM dbo.Productos WHERE id_producto=@id_producto; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Producto_Actualizar @id_producto INT,@id_categoria INT,@codigo NVARCHAR(30),@nombre NVARCHAR(150),@descripcion NVARCHAR(500)=NULL,@unidad_medida NVARCHAR(30),@precio_unitario DECIMAL(12,2),@stock_minimo INT
AS BEGIN SET NOCOUNT ON; IF NOT EXISTS(SELECT 1 FROM dbo.Categorias WHERE id_categoria=@id_categoria AND activo=1) THROW 51005,'Categoría no válida',1; IF NULLIF(TRIM(@codigo),'') IS NULL OR NULLIF(TRIM(@nombre),'') IS NULL OR NULLIF(TRIM(@unidad_medida),'') IS NULL THROW 51006,'Campos obligatorios incompletos',1; UPDATE dbo.Productos SET id_categoria=@id_categoria,codigo=TRIM(@codigo),nombre=TRIM(@nombre),descripcion=@descripcion,unidad_medida=TRIM(@unidad_medida),precio_unitario=@precio_unitario,stock_minimo=@stock_minimo WHERE id_producto=@id_producto; IF @@ROWCOUNT=0 THROW 51007,'Producto no encontrado',1; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Producto_Desactivar @id_producto INT
AS BEGIN SET NOCOUNT ON; UPDATE dbo.Productos SET activo=0 WHERE id_producto=@id_producto; IF @@ROWCOUNT=0 THROW 51008,'Producto no encontrado',1; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Lote_ListarPorProducto @id_producto INT
AS BEGIN SET NOCOUNT ON; SELECT id_lote,id_producto,numero_lote,fecha_vencimiento,stock_actual,fecha_registro,CASE WHEN fecha_vencimiento<CONVERT(date,GETDATE()) THEN 1 ELSE 0 END vencido FROM dbo.Lotes WHERE id_producto=@id_producto ORDER BY fecha_vencimiento,id_lote; END;
GO
-- Entrada: bloqueo por producto serializa los cambios de stock total.
CREATE OR ALTER PROCEDURE dbo.sp_Entrada_Registrar @id_producto INT,@id_usuario INT,@cantidad INT,@motivo NVARCHAR(200),@numero_lote NVARCHAR(50)=NULL,@fecha_vencimiento DATE=NULL
AS BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @maneja BIT,@requiere BIT,@id_lote INT,@prev INT,@nuevo INT,@fecha_existente DATE,@numero_existente NVARCHAR(50);
 BEGIN TRY
 BEGIN TRAN;
 IF @cantidad IS NULL OR @cantidad<=0 THROW 51101,'Cantidad inválida',1;
 IF NULLIF(TRIM(@motivo),'') IS NULL THROW 51102,'Motivo obligatorio',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE id_usuario=@id_usuario AND activo=1) THROW 51103,'Usuario inválido',1;
 SELECT @maneja=maneja_lotes,@requiere=requiere_vencimiento FROM dbo.Productos WITH(UPDLOCK,HOLDLOCK) WHERE id_producto=@id_producto AND activo=1;
 IF @maneja IS NULL THROW 51104,'Producto inválido o inactivo',1;
 SET @numero_lote=NULLIF(TRIM(@numero_lote),'');
 IF @maneja=1 AND @numero_lote IS NULL THROW 51105,'Número de lote obligatorio',1;
 IF @maneja=0 AND (@numero_lote IS NOT NULL OR @fecha_vencimiento IS NOT NULL) THROW 51106,'Producto sin gestión de lotes',1;
 IF @requiere=1 AND @fecha_vencimiento IS NULL THROW 51107,'Fecha de vencimiento obligatoria',1;
 IF @fecha_vencimiento IS NOT NULL AND @fecha_vencimiento<CONVERT(date,GETDATE()) THROW 51108,'No se admite ingreso ordinario de lote vencido',1;
 SELECT @prev=COALESCE(SUM(stock_actual),0) FROM dbo.Lotes WHERE id_producto=@id_producto;
 SELECT @id_lote=id_lote,@fecha_existente=fecha_vencimiento,@numero_existente=numero_lote FROM dbo.Lotes WITH(UPDLOCK,HOLDLOCK) WHERE id_producto=@id_producto AND ((@numero_lote IS NULL AND numero_lote IS NULL) OR numero_lote=@numero_lote);
 IF @id_lote IS NOT NULL
 BEGIN
  IF (@fecha_existente<>@fecha_vencimiento) OR (@fecha_existente IS NULL AND @fecha_vencimiento IS NOT NULL) OR (@fecha_existente IS NOT NULL AND @fecha_vencimiento IS NULL) THROW 51109,'Vencimiento incompatible con lote existente',1;
  UPDATE dbo.Lotes SET stock_actual=stock_actual+@cantidad WHERE id_lote=@id_lote;
 END
 ELSE BEGIN
  INSERT dbo.Lotes(id_producto,numero_lote,fecha_vencimiento,stock_actual) VALUES(@id_producto,@numero_lote,@fecha_vencimiento,@cantidad);
  SET @id_lote=CAST(SCOPE_IDENTITY() AS INT);
 END;
 SET @nuevo=@prev+@cantidad;
 INSERT dbo.Movimientos(id_producto,id_lote,id_usuario,id_area,tipo_movimiento,cantidad,motivo,stock_anterior,stock_posterior) VALUES(@id_producto,@id_lote,@id_usuario,NULL,'ENTRADA',@cantidad,@motivo,@prev,@nuevo);
 DECLARE @id_movimiento INT=CAST(SCOPE_IDENTITY() AS INT);
 COMMIT;
 SELECT @id_movimiento id_movimiento,@id_lote id_lote,@prev stock_anterior,@nuevo stock_posterior;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Salida_Registrar @id_producto INT,@id_lote INT,@id_usuario INT,@id_area INT,@cantidad INT,@motivo NVARCHAR(200)
AS BEGIN SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @requiere BIT,@stock_lote INT,@vence DATE,@prev INT,@nuevo INT;
 BEGIN TRY BEGIN TRAN;
 IF @cantidad IS NULL OR @cantidad<=0 THROW 51201,'Cantidad inválida',1;
 IF NULLIF(TRIM(@motivo),'') IS NULL THROW 51202,'Motivo obligatorio',1;
 SELECT @requiere=requiere_vencimiento FROM dbo.Productos WITH(UPDLOCK,HOLDLOCK) WHERE id_producto=@id_producto AND activo=1;
 IF @requiere IS NULL THROW 51203,'Producto inválido o inactivo',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE id_usuario=@id_usuario AND activo=1) THROW 51204,'Usuario inválido',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.AreasHospitalarias WHERE id_area=@id_area AND activo=1) THROW 51205,'Área inválida',1;
 SELECT @stock_lote=stock_actual,@vence=fecha_vencimiento FROM dbo.Lotes WITH(UPDLOCK,HOLDLOCK) WHERE id_lote=@id_lote AND id_producto=@id_producto;
 IF @stock_lote IS NULL THROW 51206,'Lote no encontrado',1;
 IF @requiere=1 AND @vence IS NULL THROW 51207,'Falta vencimiento',1;
 IF @vence<CONVERT(date,GETDATE()) THROW 51208,'Lote vencido',1;
 IF @stock_lote<@cantidad THROW 51209,'Stock insuficiente en lote',1;
 SELECT @prev=COALESCE(SUM(stock_actual),0) FROM dbo.Lotes WHERE id_producto=@id_producto;
 UPDATE dbo.Lotes SET stock_actual=stock_actual-@cantidad WHERE id_lote=@id_lote AND stock_actual>=@cantidad;
 IF @@ROWCOUNT<>1 THROW 51210,'Stock cambió durante la operación',1;
 SET @nuevo=@prev-@cantidad;
 INSERT dbo.Movimientos(id_producto,id_lote,id_usuario,id_area,tipo_movimiento,cantidad,motivo,stock_anterior,stock_posterior) VALUES(@id_producto,@id_lote,@id_usuario,@id_area,'SALIDA',@cantidad,@motivo,@prev,@nuevo);
 DECLARE @id_movimiento INT=CAST(SCOPE_IDENTITY() AS INT);
 COMMIT;
 SELECT @id_movimiento id_movimiento,@prev stock_anterior,@nuevo stock_posterior;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Movimiento_Listar @id_producto INT=NULL,@tipo_movimiento VARCHAR(10)=NULL,@id_area INT=NULL,@desde DATE=NULL,@hasta DATE=NULL
AS BEGIN SET NOCOUNT ON; SELECT m.id_movimiento,m.fecha_movimiento,m.tipo_movimiento,p.codigo,p.nombre producto,l.numero_lote,l.fecha_vencimiento,a.nombre area,u.nombre usuario,m.cantidad,m.motivo,m.stock_anterior,m.stock_posterior FROM dbo.Movimientos m JOIN dbo.Productos p ON p.id_producto=m.id_producto JOIN dbo.Lotes l ON l.id_lote=m.id_lote JOIN dbo.Usuarios u ON u.id_usuario=m.id_usuario LEFT JOIN dbo.AreasHospitalarias a ON a.id_area=m.id_area WHERE (@id_producto IS NULL OR m.id_producto=@id_producto) AND (@tipo_movimiento IS NULL OR m.tipo_movimiento=@tipo_movimiento) AND (@id_area IS NULL OR m.id_area=@id_area) AND (@desde IS NULL OR m.fecha_movimiento>=@desde) AND (@hasta IS NULL OR m.fecha_movimiento<DATEADD(day,1,CAST(@hasta AS DATETIME2))) ORDER BY m.fecha_movimiento DESC,m.id_movimiento DESC; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Producto_StockBajo
AS BEGIN SET NOCOUNT ON; SELECT p.id_producto,p.codigo,p.nombre,p.stock_minimo,COALESCE(SUM(CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento>=CONVERT(date,GETDATE()) THEN l.stock_actual ELSE 0 END),0) stock_disponible FROM dbo.Productos p LEFT JOIN dbo.Lotes l ON l.id_producto=p.id_producto WHERE p.activo=1 GROUP BY p.id_producto,p.codigo,p.nombre,p.stock_minimo HAVING COALESCE(SUM(CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento>=CONVERT(date,GETDATE()) THEN l.stock_actual ELSE 0 END),0)<=p.stock_minimo ORDER BY stock_disponible,p.nombre; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Lote_Vencimientos @dias INT=30
AS BEGIN SET NOCOUNT ON; IF @dias IS NULL OR @dias<0 OR @dias>3650 THROW 51301,'Días fuera de rango',1; SELECT p.codigo,p.nombre,l.numero_lote,l.fecha_vencimiento,l.stock_actual,CASE WHEN l.fecha_vencimiento<CONVERT(date,GETDATE()) THEN 'VENCIDO' ELSE 'PROXIMO' END estado FROM dbo.Lotes l JOIN dbo.Productos p ON p.id_producto=l.id_producto WHERE p.activo=1 AND l.stock_actual>0 AND l.fecha_vencimiento IS NOT NULL AND l.fecha_vencimiento<=DATEADD(day,@dias,CONVERT(date,GETDATE())) ORDER BY l.fecha_vencimiento; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Producto_MayoresSalidas @desde DATE,@hasta DATE
AS BEGIN SET NOCOUNT ON; IF @desde IS NULL OR @hasta IS NULL OR @desde>@hasta THROW 51302,'Rango inválido',1; SELECT p.id_producto,p.codigo,p.nombre,SUM(CAST(m.cantidad AS BIGINT)) total_salidas FROM dbo.Movimientos m JOIN dbo.Productos p ON p.id_producto=m.id_producto WHERE m.tipo_movimiento='SALIDA' AND m.fecha_movimiento>=@desde AND m.fecha_movimiento<DATEADD(day,1,CAST(@hasta AS DATETIME2)) GROUP BY p.id_producto,p.codigo,p.nombre ORDER BY total_salidas DESC; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Resumen @desde DATE=NULL,@hasta DATE=NULL
AS BEGIN SET NOCOUNT ON;
 SELECT (SELECT COUNT(*) FROM dbo.Productos WHERE activo=1) productos_activos,
 (SELECT COUNT(*) FROM (SELECT p.id_producto FROM dbo.Productos p LEFT JOIN dbo.Lotes l ON l.id_producto=p.id_producto WHERE p.activo=1 GROUP BY p.id_producto,p.stock_minimo HAVING COALESCE(SUM(CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento>=CONVERT(date,GETDATE()) THEN l.stock_actual ELSE 0 END),0)<=p.stock_minimo) x) productos_stock_bajo,
 (SELECT COUNT(*) FROM dbo.Lotes l JOIN dbo.Productos p ON p.id_producto=l.id_producto WHERE p.activo=1 AND l.stock_actual>0 AND l.fecha_vencimiento<CONVERT(date,GETDATE())) lotes_vencidos,
 (SELECT COUNT(*) FROM dbo.Lotes l JOIN dbo.Productos p ON p.id_producto=l.id_producto WHERE p.activo=1 AND l.stock_actual>0 AND l.fecha_vencimiento BETWEEN CONVERT(date,GETDATE()) AND DATEADD(day,30,CONVERT(date,GETDATE()))) lotes_proximos_vencer,
 (SELECT COALESCE(SUM(CAST(l.stock_actual AS DECIMAL(19,2))*p.precio_unitario),0) FROM dbo.Lotes l JOIN dbo.Productos p ON p.id_producto=l.id_producto WHERE p.activo=1) valor_referencial_inventario,
 (SELECT COUNT(*) FROM dbo.Movimientos m WHERE (@desde IS NULL OR m.fecha_movimiento>=@desde) AND (@hasta IS NULL OR m.fecha_movimiento<DATEADD(day,1,CAST(@hasta AS DATETIME2)))) movimientos_periodo;
END;
GO
-- Ejemplos: usuario se crea con hash real desde FastAPI, no contraseña de muestra.
-- EXEC dbo.sp_Producto_Crear @id_categoria=1,@codigo=N'MED001',@nombre=N'Paracetamol 500 mg',@unidad_medida=N'Caja',@precio_unitario=15,@stock_minimo=20,@maneja_lotes=1,@requiere_vencimiento=1;
-- EXEC dbo.sp_Entrada_Registrar @id_producto=1,@id_usuario=1,@cantidad=100,@motivo=N'Compra',@numero_lote=N'PAR-001',@fecha_vencimiento='2027-12-31';
-- EXEC dbo.sp_Salida_Registrar @id_producto=1,@id_lote=1,@id_usuario=1,@id_area=1,@cantidad=20,@motivo=N'Abastecimiento emergencia';
-- EXEC dbo.sp_Producto_Listar;
-- EXEC dbo.sp_Movimiento_Listar;
-- EXEC dbo.sp_Dashboard_Resumen;
