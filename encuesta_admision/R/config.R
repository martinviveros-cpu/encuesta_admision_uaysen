# =============================================================================
# R/config.R · Configuración de la aplicación
# Todo lo sensible se lee de variables de entorno (archivo .Renviron en local,
# "Secrets / Variables" en Posit Connect Cloud). Nunca se escribe en el código.
# =============================================================================

APP_VERSION <- "0.1.0"

# Almacenamiento: "local" (CSV en respuestas/) o "gsheet" (Google Sheets)
BACKEND <- Sys.getenv("ENCUESTA_BACKEND", "local")

# Google Sheets: ID de la planilla y credencial de cuenta de servicio
SHEET_ID        <- Sys.getenv("ENCUESTA_SHEET_ID", "")
GS_SERVICE_JSON <- Sys.getenv("ENCUESTA_GS_JSON", "")   # ruta al .json o su contenido

# Clave para la vista de resultados (separa encuesta de registros)
CLAVE_ADMIN <- Sys.getenv("ENCUESTA_CLAVE_ADMIN", "")

# Tratamiento de "Tal vez" en contacto (pendiente de validar con Admisión):
# FALSE = se registra la respuesta pero no se piden datos de contacto.
TAL_VEZ_PIDE_CONTACTO <- FALSE

# Texto de autorización (PROVISORIO hasta recibir el texto oficial de Admisión).
# Al cambiarlo, subir la versión para saber qué texto aceptó cada persona.
TEXTO_AUTORIZACION <- paste(
  "Autorizo a la Universidad de Aysén a contactarme por los medios que indico",
  "para enviarme información sobre admisión y carreras. Puedo retirar esta",
  "autorización cuando quiera."
)
VERSION_AUTORIZACION <- "v0-provisoria"

# Segundos antes de volver solo al inicio tras un envío correcto
SEGUNDOS_REINICIO <- 20

# Columnas de la planilla de respuestas (una fila por envío). El orden importa.
COLUMNAS_RESPUESTAS <- c(
  "id_envio", "fecha_hora_envio", "fecha_actividad", "rbd", "colegio", "comuna",
  "curso", "eval_relator", "eval_claridad", "eval_apoyos",
  "interes_carrera", "carreras", "n_carreras",
  "quiere_contacto", "nombre", "email", "telefono",
  "autoriza_contacto", "version_autorizacion", "version_app"
)
