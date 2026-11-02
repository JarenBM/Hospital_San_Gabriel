"""Acceso a datos de usuarios mediante procedimientos almacenados."""

import pyodbc

from backend.database import obtener_conexion
from backend.errors import DatosInvalidos
from backend.repositories.errores_sql import clasificar


def obtener_por_email(email: str) -> dict | None:
    """Ejecuta dbo.sp_Usuario_ObtenerPorEmail.

    Devuelve la fila completa (incluido ``password_hash``) o ``None`` si no
    existe. El servicio decide qué hacer con el hash; nunca llega al cliente.
    """
    try:
        with obtener_conexion() as conexion:
            cursor = conexion.cursor()
            cursor.execute("EXEC dbo.sp_Usuario_ObtenerPorEmail @email = ?", email)
            columnas = [columna[0] for columna in cursor.description]
            fila = cursor.fetchone()
            return dict(zip(columnas, fila)) if fila else None
    except pyodbc.Error as error:
        if clasificar(error) == "datos_invalidos":
            raise DatosInvalidos("El correo no tiene un formato válido") from error
        raise
