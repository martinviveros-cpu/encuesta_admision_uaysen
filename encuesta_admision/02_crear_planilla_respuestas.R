yes# =============================================================================
# 02_crear_planilla_respuestas.R
# Crea UNA vez la planilla de Google Sheets donde se guardan las respuestas.
# Se corre a mano, en RStudio, con la cuenta institucional del proyecto.
#
# Por qué Google Sheets: Posit Connect Cloud no guarda archivos entre reinicios,
# así que un CSV dentro de la app se perdería. La planilla además se abre en
# Excel (Archivo > Descargar > .xlsx) y Admisión puede verla sin entrar a la app.
#
# Pasos previos (una vez):
#   1. En Google Cloud Console crear un proyecto, habilitar "Google Sheets API"
#      y "Google Drive API", y crear una CUENTA DE SERVICIO con clave JSON.
#   2. Guardar el JSON FUERA de la carpeta del proyecto (nunca en el repositorio).
# =============================================================================

library(googlesheets4)
source("R/config.R")

gs4_auth()   # abre el navegador: entrar con la cuenta del proyecto

hoja <- gs4_create(
  name   = "Encuesta charlas Admisión UAysén - respuestas",
  sheets = list(respuestas = as.data.frame(
    setNames(replicate(length(COLUMNAS_RESPUESTAS), character(), simplify = FALSE),
             COLUMNAS_RESPUESTAS)))
)

message("Planilla creada. ID: ", as_sheets_id(hoja))
message("Ahora:")
message(" 1. Compartirla como EDITOR con el correo de la cuenta de servicio",
        " (campo client_email del JSON).")
message(" 2. Compartirla como LECTOR solo con las personas de Admisión autorizadas.")
message(" 3. Poner el ID en .Renviron (local) y en Connect Cloud: ENCUESTA_SHEET_ID=",
        as_sheets_id(hoja))
