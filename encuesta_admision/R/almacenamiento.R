# =============================================================================
# R/almacenamiento.R · Capa única de acceso a las respuestas
# La app solo llama a guardar_respuesta() y leer_respuestas(); así el mismo
# código funciona con CSV local (pruebas) o con Google Sheets (producción).
# =============================================================================

RUTA_LOCAL <- file.path("respuestas", "respuestas.csv")

# ---- Conexión a Google Sheets ----------------------------------------------
conectar_gsheet <- function() {
  if (!requireNamespace("googlesheets4", quietly = TRUE))
    stop("Falta el paquete googlesheets4.")
  if (googlesheets4::gs4_has_token()) return(invisible(TRUE))
  if (SHEET_ID == "" || GS_SERVICE_JSON == "")
    stop("Faltan ENCUESTA_SHEET_ID o ENCUESTA_GS_JSON en las variables de entorno.")
  ruta <- GS_SERVICE_JSON
  if (!file.exists(ruta)) {                    # en la nube se pega el contenido del JSON
    ruta <- tempfile(fileext = ".json")
    writeLines(GS_SERVICE_JSON, ruta)
  }
  googlesheets4::gs4_auth(path = ruta)
  invisible(TRUE)
}

# ---- Normaliza una respuesta a una fila con todas las columnas ------------
como_fila <- function(resp) {
  fila <- lapply(COLUMNAS_RESPUESTAS, function(col) {
    v <- resp[[col]]
    if (is.null(v) || length(v) == 0) NA_character_ else as.character(v[1])
  })
  names(fila) <- COLUMNAS_RESPUESTAS
  data.table::as.data.table(fila)
}

# ---- Leer --------------------------------------------------------------------
leer_respuestas <- function() {
  vacia <- data.table::as.data.table(
    setNames(replicate(length(COLUMNAS_RESPUESTAS), character(), simplify = FALSE),
             COLUMNAS_RESPUESTAS))
  dt <- if (BACKEND == "gsheet") {
    conectar_gsheet()
    data.table::as.data.table(
      googlesheets4::read_sheet(SHEET_ID, sheet = "respuestas",
                                col_types = "c", .name_repair = "minimal"))
  } else {
    if (!file.exists(RUTA_LOCAL)) return(vacia)
    data.table::fread(RUTA_LOCAL, colClasses = "character", encoding = "UTF-8")
  }
  if (nrow(dt) == 0) return(vacia)
  faltan <- setdiff(COLUMNAS_RESPUESTAS, names(dt))
  for (f in faltan) dt[, (f) := NA_character_]
  dt[, ..COLUMNAS_RESPUESTAS]
}

# ¿Ya existe este envío? Evita duplicados al reintentar.
existe_envio <- function(id) {
  if (BACKEND == "gsheet") {
    conectar_gsheet()
    ids <- googlesheets4::range_read(SHEET_ID, sheet = "respuestas",
                                     range = "A:A", col_types = "c")[[1]]
  } else {
    if (!file.exists(RUTA_LOCAL)) return(FALSE)
    ids <- data.table::fread(RUTA_LOCAL, select = "id_envio",
                             colClasses = "character")[[1]]
  }
  id %in% ids
}

# ---- Guardar ---------------------------------------------------------------
# Devuelve "guardado" o "ya_existia". Si falla, lanza error (la app lo muestra
# y permite reintentar con el MISMO id_envio, sin duplicar).
guardar_respuesta <- function(resp) {
  fila <- como_fila(resp)
  if (existe_envio(fila$id_envio)) return("ya_existia")
  if (BACKEND == "gsheet") {
    conectar_gsheet()
    googlesheets4::sheet_append(SHEET_ID, fila, sheet = "respuestas")
  } else {
    dir.create(dirname(RUTA_LOCAL), showWarnings = FALSE, recursive = TRUE)
    data.table::fwrite(fila, RUTA_LOCAL, append = file.exists(RUTA_LOCAL),
                       bom = !file.exists(RUTA_LOCAL))
  }
  "guardado"
}
