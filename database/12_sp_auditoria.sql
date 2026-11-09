-- SIGIH | 12 - Auditoría
-- Solo registro en esta fase; el listado se difiere a la siguiente.
-- El registro es best-effort: nunca debe tumbar la operación principal.

USE SIGIH;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auditoria_Registrar
    @id_usuario INT = NULL,
    @accion     NVARCHAR(50),
    @modulo     NVARCHAR(50),
    @id_registro NVARCHAR(50) = NULL,
    @detalle    NVARCHAR(500) = NULL,
    @ip         NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NULLIF(TRIM(@accion), N'') IS NULL
           OR NULLIF(TRIM(@modulo), N'') IS NULL
            RETURN;

        IF @id_usuario IS NOT NULL
           AND NOT EXISTS (
               SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario
           )
            SET @id_usuario = NULL;

        INSERT dbo.Auditoria
        (
            id_usuario, accion, modulo, id_registro, detalle, ip
        )
        VALUES
        (
            @id_usuario,
            LEFT(TRIM(@accion), 50),
            LEFT(TRIM(@modulo), 50),
            LEFT(@id_registro, 50),
            LEFT(@detalle, 500),
            LEFT(@ip, 45)
        );
    END TRY
    BEGIN CATCH
        -- Best-effort: se ignoran los fallos de auditoría.
    END CATCH
END;
GO

PRINT N'12_sp_auditoria.sql ejecutado.';
GO
