# =============================================================================
# pruebas/pruebas_basicas.R · Pruebas rápidas sin abrir la app
# Correr desde el proyecto:  source("pruebas/pruebas_basicas.R")
# Usa un archivo de respuestas temporal: no toca las respuestas reales.
# =============================================================================
library(data.table); library(shiny)
source("R/config.R"); source("R/almacenamiento.R"); source("R/encuesta.R")

BACKEND    <- "local"
RUTA_LOCAL <- tempfile(fileext = ".csv")

ok <- function(cond, txt) cat(if (isTRUE(cond)) "OK   " else "FALLA", txt, "\n")

# 1. Catálogos
car <- fread("data/carreras.csv", sep = ",", encoding = "UTF-8")
ok("Tecnología Médica" %in% car$carrera, "Tecnología Médica está en el catálogo")
ok(!"Pedagogía en Inglés" %in% car$carrera, "Pedagogía en Inglés no está")

# 2. Guardado sin duplicar
r <- list(id_envio = "prueba-1", curso = "4° medio", carreras = "Derecho; Psicología")
ok(guardar_respuesta(r) == "guardado",   "primer envío se guarda")
ok(guardar_respuesta(r) == "ya_existia", "reintento con el mismo id no duplica")
ok(nrow(leer_respuestas()) == 1,         "hay una sola fila")
ok(identical(names(leer_respuestas()), COLUMNAS_RESPUESTAS), "columnas en el orden acordado")

# 3. Validaciones de contacto
ok(is.null(validar_contacto("No", "", "", "", FALSE)),            "No: no pide datos")
ok(!is.null(validar_contacto("Sí", "", "a@b.cl", "", TRUE)),      "Sí sin nombre: error")
ok(!is.null(validar_contacto("Sí", "Ana", "", "", TRUE)),         "Sí sin correo ni teléfono: error")
ok(!is.null(validar_contacto("Sí", "Ana", "a@b", "", TRUE)),      "correo mal escrito: error")
ok(!is.null(validar_contacto("Sí", "Ana", "a@b.cl", "", FALSE)),  "sin autorización: error")
ok(is.null(validar_contacto("Sí", "Ana", "", "+56912345678", TRUE)), "teléfono válido: ok")
