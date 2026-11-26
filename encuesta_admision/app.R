# =============================================================================
# app.R · Encuesta de charlas de Admisión UAysén
#
# Dos vistas en una misma aplicación, separadas por el enlace:
#   <enlace>                       -> encuesta para tablets (estudiantes)
#   <enlace>?rbd=8345&fecha=AAAA-MM-DD -> encuesta con colegio y fecha precargados
#   <enlace>?vista=admision        -> resultados para Admisión (pide clave)
#
# Antes de correrla: source("01_preparar_catalogos.R") una vez.
# =============================================================================
#install.packages("shinyjs")
#install.packages("bslib")

library(shiny)
library(bslib)
library(data.table)
library(ggplot2)

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f, encoding = "UTF-8")

# ---- Catálogos ya preparados (la app no limpia datos) ------------------------
if (!file.exists("data/carreras.csv"))
  stop("Faltan los catálogos: corre primero source('01_preparar_catalogos.R').")
catalogos <- list(
  carreras  = fread("data/carreras.csv",  sep = ",", encoding = "UTF-8", colClasses = "character"),
  colegios  = fread("data/colegios.csv",  sep = ",", encoding = "UTF-8", colClasses = "character"),
  cursos    = fread("data/cursos.csv",    sep = ",", encoding = "UTF-8"),
  preguntas = fread("data/preguntas.csv", sep = ",", encoding = "UTF-8"),
  info      = fread("data/catalogos_info.csv", sep = ",", encoding = "UTF-8")
)

# Lee la actividad precargada desde el enlace (?rbd=...&fecha=...)
actividad_desde_url <- function(qs) {
  rbd_url <- qs$rbd
  if (is.null(rbd_url) || !rbd_url %in% catalogos$colegios$rbd) return(list())
  fila  <- catalogos$colegios[rbd == rbd_url]
  fecha <- tryCatch(as.Date(qs$fecha), error = function(e) NA)
  list(rbd = rbd_url, colegio = fila$colegio, comuna = fila$comuna,
       fecha = if (is.null(qs$fecha) || is.na(fecha)) Sys.Date() else fecha)
}

es_admin <- function(qs) identical(qs$vista, "admision")

ui <- function(request) {
  qs <- parseQueryString(request$QUERY_STRING)
  if (es_admin(qs)) resultados_ui(catalogos)
  else encuesta_ui(catalogos, actividad_desde_url(qs))
}

server <- function(input, output, session) {
  qs <- parseQueryString(isolate(session$clientData$url_search))
  if (es_admin(qs)) resultados_server(input, output, session, catalogos)
  else encuesta_server(input, output, session, catalogos, actividad_desde_url(qs))
}

shinyApp(ui, server)
