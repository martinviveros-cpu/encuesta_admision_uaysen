# =============================================================================
# 01_preparar_catalogos.R
# Prepara, FUERA de la aplicación, los catálogos que la encuesta necesita.
# La app solo lee los archivos de data/ y no limpia nada al arrancar.
#
# Entrada  (data_raw/):
#   - carreras_uaysen.csv               catálogo de carreras (dim_carrera, EP2)
#   - directorio_mineduc_aysen_2025.csv directorio de establecimientos MINEDUC 2025
# Salida   (data/):
#   - carreras.csv    carreras que se muestran en la encuesta, en orden
#   - colegios.csv    establecimientos con enseñanza media de Aysén
#   - cursos.csv      opciones de curso
#   - preguntas.csv   redacción y escala de las preguntas de evaluación
#   - catalogos_info.csv  fecha y conteos de control
#
# Cómo correrlo: abrir encuesta_admision.Rproj y ejecutar
#   source("01_preparar_catalogos.R")
# =============================================================================

library(data.table)

dir.create("data", showWarnings = FALSE)

# ---- 1. Carreras -------------------------------------------------------------
# Decisiones del acta (20-11-2026): incorporar Tecnología Médica y retirar
# Pedagogía en Inglés. Admisión debe confirmar el catálogo vigente: si cambia,
# se edita SOLO esta sección (o data_raw/carreras_uaysen.csv) y se vuelve a correr.
carreras_raw <- fread("data_raw/carreras_uaysen.csv", encoding = "UTF-8")

carreras <- carreras_raw[, .(codigo = as.character(CODIGO_CARRERA),
                             carrera = trimws(carrera))]
carreras[, carrera := sub("\\s*\\(Nueva\\)$", "", carrera)]   # "Tecnología Médica (Nueva)"
carreras[carrera == "Tecnología Médica" & codigo == "0", codigo := "TM"]

retirar  <- c("Pedagogía en Inglés")
agregar  <- data.table(codigo = "TM", carrera = "Tecnología Médica")

carreras <- carreras[!carrera %in% retirar]
carreras <- unique(rbind(carreras, agregar[!carrera %in% carreras$carrera]))
setorder(carreras, carrera)
carreras[, orden := .I]

stopifnot(!anyDuplicated(carreras$carrera),
          "Tecnología Médica" %in% carreras$carrera,
          !"Pedagogía en Inglés" %in% carreras$carrera)

fwrite(carreras, "data/carreras.csv", bom = TRUE)

# ---- 2. Colegios -------------------------------------------------------------
# Se usan para precargar el colegio de la actividad (enlace de la tablet).
dir_mineduc <- fread("data_raw/directorio_mineduc_aysen_2025.csv", encoding = "UTF-8")

colegios <- dir_mineduc[ESTADO_ESTAB == 1 & mat_media_total > 0,
                        .(rbd = as.character(RBD),
                          colegio = tools::toTitleCase(tolower(trimws(NOM_RBD))),
                          comuna  = tools::toTitleCase(tolower(trimws(NOM_COM_RBD))))]
colegios <- rbind(colegios,
                  data.table(rbd = "0", colegio = "Otro establecimiento / actividad abierta",
                             comuna = "Sin comuna"))
setorder(colegios, comuna, colegio)
stopifnot(!anyDuplicated(colegios$rbd), nrow(colegios) > 1)

fwrite(colegios, "data/colegios.csv", bom = TRUE)

# ---- 3. Cursos ---------------------------------------------------------------
cursos <- data.table(curso = c("3° medio", "4° medio", "Educación de adultos",
                               "Egresado/a", "Otro"))
fwrite(cursos, "data/cursos.csv", bom = TRUE)

# ---- 4. Preguntas de evaluación ---------------------------------------------
# Redacción del acta; escala 1 a 7 PROPUESTA (pendiente de validar con la
# encuesta vigente de Admisión). Cambiar texto o escala aquí, no en app.R.
preguntas <- data.table(
  id    = c("eval_relator", "eval_claridad", "eval_apoyos"),
  texto = c("¿Cómo evalúas al relator o relatora?",
            "¿La información se presentó con claridad?",
            "¿Los apoyos tecnológicos fueron adecuados?"),
  escala_min = 1L,
  escala_max = 7L,
  etiqueta_min = "Muy malo",
  etiqueta_max = "Excelente"
)
fwrite(preguntas, "data/preguntas.csv", bom = TRUE)

# ---- 5. Control --------------------------------------------------------------
info <- data.table(
  generado   = format(Sys.time(), "%Y-%m-%d %H:%M"),
  n_carreras = nrow(carreras),
  n_colegios = nrow(colegios) - 1L,
  fuente_carreras = "Catálogo dim_carrera (EP2) + acta 20-11-2026",
  fuente_colegios = "Directorio de establecimientos MINEDUC 2025"
)
fwrite(info, "data/catalogos_info.csv", bom = TRUE)

message("Catálogos listos: ", nrow(carreras), " carreras, ",
        nrow(colegios) - 1L, " establecimientos con enseñanza media.")
