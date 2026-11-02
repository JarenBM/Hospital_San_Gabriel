-- SIGIH | 14 - Catálogos iniciales
-- Idempotente: no duplica categorías ni áreas existentes.

USE SIGIH;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Medicamentos')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Medicamentos', N'Medicamentos de uso hospitalario');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material médico')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material médico', N'Insumos médicos');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Material de laboratorio')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Material de laboratorio', N'Insumos de laboratorio');

IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre = N'Limpieza hospitalaria')
    INSERT dbo.Categorias (nombre, descripcion)
    VALUES (N'Limpieza hospitalaria', N'Productos de limpieza');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Emergencia')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Emergencia');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Hospitalización')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Hospitalización');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Consultorios externos')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Consultorios externos');

IF NOT EXISTS (SELECT 1 FROM dbo.AreasHospitalarias WHERE nombre = N'Laboratorio')
    INSERT dbo.AreasHospitalarias (nombre) VALUES (N'Laboratorio');

PRINT N'14_seed_catalogos.sql ejecutado.';
GO
