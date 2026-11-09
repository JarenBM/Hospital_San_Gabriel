-- SIGIH | 17 - Usuario de aplicación sigih_app
-- Ejecutar SIEMPRE con la variable APP_PASSWORD:
--   sqlcmd -S .\SQLEXPRESS -E -C -i database\17_permisos_app.sql -v APP_PASSWORD="UnaClaveFuerte.2026!"
--
-- El usuario solo puede ejecutar SPs del esquema dbo. No puede leer ni
-- modificar tablas directamente (defensa en profundidad además del RBAC).
-- Idempotente: crea o actualiza el login y vuelve a aplicar los permisos.

USE master;
GO

DECLARE @password NVARCHAR(128) = N'$(APP_PASSWORD)';

IF @password = N''
   OR CHARINDEX(N'$' + N'(', @password) > 0
    THROW 51801, N'Defina APP_PASSWORD al ejecutar el script: sqlcmd ... -v APP_PASSWORD="..."', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.server_principals WHERE name = N'sigih_app'
)
BEGIN
    DECLARE @crear NVARCHAR(MAX) =
        N'CREATE LOGIN [sigih_app] WITH PASSWORD = N'''
        + REPLACE(@password, N'''', N'''''')
        + N''', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
    EXEC sp_executesql @crear;
END
ELSE
BEGIN
    DECLARE @alterar NVARCHAR(MAX) =
        N'ALTER LOGIN [sigih_app] WITH PASSWORD = N'''
        + REPLACE(@password, N'''', N'''''')
        + N''', CHECK_POLICY = OFF;';
    EXEC sp_executesql @alterar;
END;
GO

USE SIGIH;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = N'sigih_app'
)
BEGIN
    CREATE USER [sigih_app] FOR LOGIN [sigih_app] WITH DEFAULT_SCHEMA = dbo;
END;
GO

GRANT CONNECT TO [sigih_app];
GO

-- Solo procedimientos almacenados.
GRANT EXECUTE ON SCHEMA::dbo TO [sigih_app];
GO

-- Sin acceso directo a tablas ni vistas.
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [sigih_app];
GO

PRINT N'17_permisos_app.sql ejecutado.';
GO
