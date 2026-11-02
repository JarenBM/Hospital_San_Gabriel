-- SIGIH | Procedimientos de categorías: obtener, actualizar y desactivar.
-- Solo crea procedimientos nuevos. No modifica tablas ni SPs existentes.
-- Ejecutar manualmente en SSMS sobre la base SIGIH.

USE SIGIH;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Obtener @id_categoria INT
AS BEGIN SET NOCOUNT ON;
  SELECT id_categoria,nombre,descripcion,activo
  FROM dbo.Categorias WHERE id_categoria=@id_categoria;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Actualizar
  @id_categoria INT,@nombre NVARCHAR(100),@descripcion NVARCHAR(255)=NULL,@activo BIT=NULL
AS BEGIN SET NOCOUNT ON;
  IF NULLIF(TRIM(@nombre),'') IS NULL THROW 51401,'Nombre de categoría requerido',1;
  IF EXISTS(SELECT 1 FROM dbo.Categorias
            WHERE nombre=TRIM(@nombre) AND id_categoria<>@id_categoria)
    THROW 51402,'Ya existe una categoría con ese nombre',1;
  UPDATE dbo.Categorias
     SET nombre=TRIM(@nombre),
         descripcion=@descripcion,
         activo=COALESCE(@activo,activo)   -- NULL = conservar el estado actual
   WHERE id_categoria=@id_categoria;
  IF @@ROWCOUNT=0 THROW 51403,'Categoría no encontrada',1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Desactivar @id_categoria INT
AS BEGIN SET NOCOUNT ON;
  UPDATE dbo.Categorias SET activo=0 WHERE id_categoria=@id_categoria;
  IF @@ROWCOUNT=0 THROW 51403,'Categoría no encontrada',1;
END;
GO
