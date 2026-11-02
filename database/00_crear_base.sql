-- SIGIH | 00 - Creación de la base de datos
-- Idempotente: se puede ejecutar varias veces.
-- Ejecutar con: sqlcmd -S .\SQLEXPRESS -E -C -i database\00_crear_base.sql

IF DB_ID(N'SIGIH') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE SIGIH');
END;
GO

USE SIGIH;
GO

PRINT N'Base de datos SIGIH lista.';
GO
