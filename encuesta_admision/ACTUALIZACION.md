# Cómo actualizar y volver a publicar

## Cambiar carreras, colegios, cursos o preguntas
1. Editar `data_raw/carreras_uaysen.csv` o la sección correspondiente de `01_preparar_catalogos.R`
   (preguntas y escala están en la sección 4; cursos en la 3).
2. Correr `source("01_preparar_catalogos.R")` y revisar el mensaje final.
3. Correr `source("pruebas/pruebas_basicas.R")`: todo debe decir OK.
4. Probar con `shiny::runApp()`.

## Cambiar el texto de autorización
Editar `TEXTO_AUTORIZACION` en `R/config.R` y subir `VERSION_AUTORIZACION`
(cada respuesta guarda qué versión aceptó).

## Nuevo año
1. Actualizar el directorio MINEDUC en `data_raw/directorio_mineduc_aysen_2025.csv`
   (mismo formato) y el nombre de la fuente en la sección 5 de `01_preparar_catalogos.R`.
2. Crear una planilla nueva con `02_crear_planilla_respuestas.R` (o archivar la pestaña
   del año anterior) y cambiar `ENCUESTA_SHEET_ID` en Connect Cloud.

## Volver a publicar en Posit Connect Cloud
1. `rsconnect::writeManifest()` en la carpeta del proyecto.
2. Commit y push a GitHub (sin `.Renviron`, sin JSON, sin `respuestas/`).
3. En connect.posit.cloud, la app se vuelve a publicar con "Republish"
   (o sola si está activado el despliegue automático al hacer push).
4. Abrir el enlace desde otro computador y hacer un envío de prueba.
