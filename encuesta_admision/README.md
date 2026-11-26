# Encuesta de charlas · Admisión UAysén (Shiny)

Aplicación para que los estudiantes respondan en una tablet la encuesta de las
charlas de Admisión, y para que Admisión revise y descargue las respuestas.

## Estructura

| Archivo | Para qué |
|---|---|
| `encuesta_admision.Rproj` | Abrir siempre el proyecto desde aquí (rutas relativas) |
| `01_preparar_catalogos.R` | Prepara `data/` (carreras, colegios, cursos, preguntas). Se corre fuera de la app |
| `02_crear_planilla_respuestas.R` | Crea una vez la planilla de Google Sheets de respuestas |
| `app.R` | La aplicación |
| `R/config.R` | Configuración (lee variables de entorno) y textos editables |
| `R/almacenamiento.R` | Guardar y leer respuestas (CSV local o Google Sheets) |
| `R/encuesta.R` | Vista de la encuesta para tablets |
| `R/resultados.R` | Vista de resultados para Admisión y "Acerca de" |
| `www/tablet.css` | Letra grande, contraste y botones para tablets |
| `pruebas/pruebas_basicas.R` | Pruebas rápidas sin abrir la app |
| `data_raw/` | Insumos originales de los catálogos |
| `respuestas/` | Respuestas en modo local (no se sube al repositorio) |

## Correrla en el computador

1. Abrir `encuesta_admision.Rproj`.
2. `install.packages(c("shiny","bslib","data.table","ggplot2","DT","shinyjs","uuid","writexl","googlesheets4"))`
3. `source("01_preparar_catalogos.R")`
4. `shiny::runApp()`

Enlaces:

- Encuesta: `http://127.0.0.1:PUERTO/`
- Encuesta con colegio y fecha: `...?rbd=8345&fecha=2026-11-27`
- Resultados: `...?vista=admision` (clave en `ENCUESTA_CLAVE_ADMIN`; sin clave configurada, en modo prueba es `prueba`)

## Configuración

Copiar `.Renviron.ejemplo` como `.Renviron` y completar. Nunca subir `.Renviron` ni el JSON de la cuenta de servicio al repositorio.
