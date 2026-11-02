-- SIGIH | Procedimiento para listar áreas hospitalarias.
-- Solo crea un procedimiento nuevo. No modifica tablas ni SPs existentes.
-- Ejecutar manualmente en SSMS sobre la base SIGIH.
-- PENDIENTE: incorporar este procedimiento al script maestro de instalación de SIGIH.

USE SIGIH;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Area_Listar
AS BEGIN SET NOCOUNT ON;
  SELECT id_area,nombre,activo FROM dbo.AreasHospitalarias ORDER BY nombre;
END;
GO
