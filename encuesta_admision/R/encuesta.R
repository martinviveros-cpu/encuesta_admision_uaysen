# =============================================================================
# R/encuesta.R · Vista de la encuesta para tablets (lo que ve el estudiante)
# Recorrido: Inicio -> Evaluación -> Interés -> Contacto -> Confirmación
# Esta vista NUNCA lee ni muestra respuestas guardadas.
# =============================================================================

# Escala 1..7 como botones grandes
pregunta_escala <- function(p) {
  div(class = "pregunta",
      tags$label(class = "pregunta-texto", `for` = p$id, p$texto),
      radioButtons(p$id, label = NULL, inline = TRUE, selected = character(0),
                   choices = as.character(seq(p$escala_min, p$escala_max))),
      div(class = "escala-etiquetas",
          span(p$etiqueta_min), span(p$etiqueta_max)))
}

encuesta_ui <- function(catalogos, actividad) {
  preguntas <- catalogos$preguntas
  page_fillable(
    title = "Encuesta charlas · Admisión UAysén",
    theme = bs_theme(version = 5, base_font = font_collection("system-ui", "sans-serif"),
                     primary = "#00566B", "font-size-base" = "1.25rem"),
    shinyjs::useShinyjs(),
    tags$head(tags$link(rel = "stylesheet", href = "tablet.css"),
              tags$meta(name = "viewport",
                        content = "width=device-width, initial-scale=1, maximum-scale=1")),
    div(class = "encuesta",
      div(class = "encabezado", "Universidad de Aysén · Admisión"),
      div(id = "formulario",
        tabsetPanel(id = "paso", type = "hidden",

          # 1. Inicio ---------------------------------------------------------
          tabPanelBody("inicio",
            h1("¡Gracias por venir a la charla!"),
            p("Responder te tomará unos 2 minutos. Tus respuestas nos ayudan",
              "a mejorar las charlas."),
            if (is.null(actividad$rbd)) {
              selectInput("rbd_manual", "Colegio de la actividad",
                          choices = c("Elige tu colegio" = "",
                                      setNames(catalogos$colegios$rbd,
                                               catalogos$colegios$colegio)))
            } else {
              p(class = "actividad", strong("Colegio: "), actividad$colegio,
                br(), strong("Fecha: "), format(actividad$fecha, "%d-%m-%Y"))
            },
            radioButtons("curso", "¿En qué curso estás?", selected = character(0),
                         choices = catalogos$cursos$curso),
            uiOutput("error_inicio"),
            actionButton("btn_comenzar", "Comenzar", class = "btn-primary btn-grande")
          ),

          # 2. Evaluación -----------------------------------------------------
          tabPanelBody("evaluacion",
            h2("Evaluación de la charla"),
            p(class = "ayuda", "1 es la nota más baja y 7 la más alta."),
            lapply(seq_len(nrow(preguntas)), function(i) pregunta_escala(preguntas[i])),
            uiOutput("error_evaluacion"),
            div(class = "botonera",
                actionButton("atras_eval", "Atrás", class = "btn-outline-secondary btn-grande"),
                actionButton("btn_eval", "Siguiente", class = "btn-primary btn-grande"))
          ),

          # 3. Interés en carreras -------------------------------------------
          tabPanelBody("interes",
            h2("Carreras"),
            radioButtons("interes_carrera",
                         "¿Te interesa alguna carrera de la Universidad de Aysén?",
                         choices = c("Sí", "No"), selected = character(0), inline = TRUE),
            conditionalPanel("input.interes_carrera == 'Sí'",
              checkboxGroupInput("carreras", "¿Cuáles? Puedes marcar varias.",
                                 choices = catalogos$carreras$carrera)),
            uiOutput("error_interes"),
            div(class = "botonera",
                actionButton("atras_interes", "Atrás", class = "btn-outline-secondary btn-grande"),
                actionButton("btn_interes", "Siguiente", class = "btn-primary btn-grande"))
          ),

          # 4. Contacto y autorización ---------------------------------------
          tabPanelBody("contacto",
            h2("Contacto"),
            radioButtons("quiere_contacto",
                         "¿Te interesa que Admisión te contacte?",
                         choices = c("Sí", "No", "Tal vez"), selected = character(0),
                         inline = TRUE),
            conditionalPanel(
              if (TAL_VEZ_PIDE_CONTACTO) "input.quiere_contacto != 'No'"
              else "input.quiere_contacto == 'Sí'",
              textInput("nombre", "Nombre", placeholder = "Tu nombre"),
              textInput("email", "Correo electrónico", placeholder = "nombre@correo.cl"),
              textInput("telefono", "Teléfono (opcional si das correo)",
                        placeholder = "9 1234 5678"),
              div(class = "autorizacion", p(TEXTO_AUTORIZACION),
                  checkboxInput("autoriza", "Sí, autorizo", value = FALSE))
            ),
            uiOutput("error_contacto"),
            div(class = "botonera",
                actionButton("atras_contacto", "Atrás", class = "btn-outline-secondary btn-grande"),
                actionButton("btn_enviar", "Enviar respuestas", class = "btn-success btn-grande"))
          ),

          # 5. Confirmación ---------------------------------------------------
          tabPanelBody("final",
            uiOutput("estado_envio"),
            actionButton("btn_nueva", "Nueva encuesta", class = "btn-primary btn-grande")
          )
        )
      ),
      div(class = "pie", actionLink("ver_acerca", "Acerca de esta encuesta"))
    )
  )
}

# ---- Validaciones (funciones puras, se pueden probar sin la app) ---------
email_valido    <- function(x) grepl("^[^@\\s]+@[^@\\s]+\\.[A-Za-z]{2,}$", trimws(x), perl = TRUE)
telefono_valido <- function(x) grepl("^\\+?[0-9 ]{8,15}$", trimws(x))

validar_contacto <- function(quiere, nombre, email, telefono, autoriza) {
  if (is.null(quiere) || quiere == "") return("Elige Sí, No o Tal vez.")
  pide <- quiere == "Sí" || (quiere == "Tal vez" && TAL_VEZ_PIDE_CONTACTO)
  if (!pide) return(NULL)
  if (trimws(nombre) == "") return("Escribe tu nombre.")
  if (trimws(email) == "" && trimws(telefono) == "")
    return("Deja al menos un correo o un teléfono.")
  if (trimws(email) != "" && !email_valido(email)) return("Revisa el correo: falta algo.")
  if (trimws(telefono) != "" && !telefono_valido(telefono))
    return("El teléfono debe tener solo números (8 a 15 dígitos).")
  if (!isTRUE(autoriza)) return("Para que te contactemos, marca la autorización.")
  NULL
}

# ---- Servidor de la encuesta --------------------------------------------
encuesta_server <- function(input, output, session, catalogos, actividad) {
  id_envio <- reactiveVal(NULL)
  estado   <- reactiveVal("pendiente")   # pendiente / guardado / error
  errores  <- reactiveValues()

  mostrar_error <- function(paso, msg) errores[[paso]] <- msg
  for (p in c("inicio", "evaluacion", "interes", "contacto")) local({
    paso <- p
    output[[paste0("error_", paso)]] <- renderUI({
      if (!is.null(errores[[paso]])) div(class = "alerta", role = "alert", errores[[paso]])
    })
  })
  ir <- function(paso) {
    updateTabsetPanel(session, "paso", selected = paso)
    shinyjs::runjs("window.scrollTo(0,0);")
  }

  colegio_actual <- reactive({
    if (!is.null(actividad$rbd)) return(actividad)
    req(input$rbd_manual)
    fila <- catalogos$colegios[rbd == input$rbd_manual]
    list(rbd = fila$rbd, colegio = fila$colegio, comuna = fila$comuna,
         fecha = Sys.Date())
  })

  observeEvent(input$btn_comenzar, {
    if (is.null(actividad$rbd) && (is.null(input$rbd_manual) || input$rbd_manual == ""))
      return(mostrar_error("inicio", "Elige el colegio de la actividad."))
    if (is.null(input$curso)) return(mostrar_error("inicio", "Elige tu curso."))
    mostrar_error("inicio", NULL)
    if (is.null(id_envio())) id_envio(uuid::UUIDgenerate())
    ir("evaluacion")
  })

  observeEvent(input$btn_eval, {
    faltan <- vapply(catalogos$preguntas$id, function(id) is.null(input[[id]]), logical(1))
    if (any(faltan)) return(mostrar_error("evaluacion",
                                          "Responde las tres preguntas para seguir."))
    mostrar_error("evaluacion", NULL); ir("interes")
  })

  observeEvent(input$btn_interes, {
    if (is.null(input$interes_carrera))
      return(mostrar_error("interes", "Elige Sí o No."))
    if (input$interes_carrera == "Sí" && length(input$carreras) == 0)
      return(mostrar_error("interes", "Marca al menos una carrera, o responde No."))
    mostrar_error("interes", NULL); ir("contacto")
  })

  observeEvent(input$atras_eval,     ir("inicio"))
  observeEvent(input$atras_interes,  ir("evaluacion"))
  observeEvent(input$atras_contacto, ir("interes"))

  # Arma la fila a guardar a partir de lo que hay en pantalla
  armar_respuesta <- function() {
    act <- colegio_actual()
    carreras <- if (identical(input$interes_carrera, "Sí")) input$carreras else character(0)
    pide <- input$quiere_contacto == "Sí" ||
      (input$quiere_contacto == "Tal vez" && TAL_VEZ_PIDE_CONTACTO)
    list(
      id_envio = id_envio(),
      fecha_hora_envio = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "America/Santiago"),
      fecha_actividad = format(act$fecha), rbd = act$rbd, colegio = act$colegio,
      comuna = act$comuna, curso = input$curso,
      eval_relator = input$eval_relator, eval_claridad = input$eval_claridad,
      eval_apoyos = input$eval_apoyos,
      interes_carrera = input$interes_carrera,
      carreras = paste(carreras, collapse = "; "), n_carreras = length(carreras),
      quiere_contacto = input$quiere_contacto,
      nombre   = if (pide) trimws(input$nombre) else "",
      email    = if (pide) tolower(trimws(input$email)) else "",
      telefono = if (pide) gsub(" ", "", input$telefono) else "",
      autoriza_contacto = if (pide && isTRUE(input$autoriza)) "Sí" else "No",
      version_autorizacion = if (pide) VERSION_AUTORIZACION else "",
      version_app = APP_VERSION
    )
  }

  observeEvent(input$btn_enviar, {
    msg <- validar_contacto(input$quiere_contacto, input$nombre, input$email,
                            input$telefono, input$autoriza)
    if (!is.null(msg)) return(mostrar_error("contacto", msg))
    mostrar_error("contacto", NULL)
    shinyjs::disable("btn_enviar")
    on.exit(shinyjs::enable("btn_enviar"))
    resultado <- tryCatch(
      withProgress(message = "Guardando tus respuestas…", value = 0.5,
                   guardar_respuesta(armar_respuesta())),
      error = function(e) { message("Error al guardar: ", conditionMessage(e)); "error" })
    if (resultado == "error") {
      mostrar_error("contacto", paste("No se pudo guardar. Revisa la conexión a internet",
                                      "y toca Enviar otra vez: no se duplicará."))
      return()
    }
    estado("guardado"); ir("final")
  })

  output$estado_envio <- renderUI({
    if (estado() == "guardado") div(class = "confirmacion",
      h1("¡Listo! Tus respuestas quedaron guardadas."),
      p("Gracias por participar. Entrega la tablet a la siguiente persona."))
  })

  reiniciar <- function() {
    colegio_elegido <- isolate(input$rbd_manual)   # el colegio se mantiene en la tablet
    shinyjs::reset("formulario")      # limpia todos los campos
    if (!is.null(colegio_elegido))
      updateSelectInput(session, "rbd_manual", selected = colegio_elegido)
    updateRadioButtons(session, "curso", selected = character(0))
    for (id in c(catalogos$preguntas$id, "interes_carrera", "quiere_contacto"))
      updateRadioButtons(session, id, selected = character(0))
    updateCheckboxGroupInput(session, "carreras", selected = character(0))
    for (p in names(reactiveValuesToList(errores))) errores[[p]] <- NULL
    id_envio(NULL); estado("pendiente"); ir("inicio")
  }
  observeEvent(input$btn_nueva, reiniciar())

  # Vuelve solo al inicio tras unos segundos en la confirmación
  # (solo si nadie empezó otra encuesta mientras tanto)
  observeEvent(estado(), {
    if (estado() != "guardado") return()
    id_terminado <- id_envio()
    shinyjs::delay(SEGUNDOS_REINICIO * 1000, {
      if (identical(isolate(estado()), "guardado") &&
          identical(isolate(id_envio()), id_terminado)) reiniciar()
    })
  })

  observeEvent(input$ver_acerca, showModal(modalDialog(
    title = "Acerca de esta encuesta", easyClose = TRUE, footer = modalButton("Cerrar"),
    p("Encuesta de la Unidad de Admisión de la Universidad de Aysén para evaluar",
      "las charlas en colegios y conocer el interés por sus carreras."),
    p("Tus datos de contacto solo se usan si marcas la autorización, y solo los",
      "ve el equipo de Admisión."))))
}
