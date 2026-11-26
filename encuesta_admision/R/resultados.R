# =============================================================================
# R/resultados.R · Vista de resultados para Admisión (protegida con clave)
# Se abre con  <enlace de la app>?vista=admision
# =============================================================================

# Textos de las tablas en español (sin depender de internet)
DT_ES <- list(search = "Buscar:", lengthMenu = "Mostrar _MENU_ filas",
              info = "Filas _START_ a _END_ de _TOTAL_", infoEmpty = "Sin filas",
              infoFiltered = "(filtrado de _MAX_)", zeroRecords = "Sin coincidencias",
              paginate = list(previous = "Anterior", `next` = "Siguiente"))

resultados_ui <- function(catalogos) {
  page_navbar(
    title = "Resultados encuesta · Admisión UAysén",
    theme = bs_theme(version = 5, primary = "#00566B"),
    header = tagList(shinyjs::useShinyjs(),
                     if ("useBusyIndicators" %in% getNamespaceExports("bslib"))
                       bslib::useBusyIndicators()),
    nav_panel("Resultados",
              conditionalPanel("!output.autenticado", panel_login()),
              conditionalPanel("output.autenticado", panel_resultados(catalogos))),
    nav_panel("Enlace para tablets",
              conditionalPanel("!output.autenticado",
                               p(class = "m-4", "Entra con la clave en la pestaña Resultados.")),
              conditionalPanel("output.autenticado", panel_enlace(catalogos))),
    nav_panel("Acerca de", acerca_de_ui(catalogos))
  )
}

panel_login <- function() {
  card(class = "mx-auto mt-5", style = "max-width: 420px;",
       card_header("Acceso de Admisión"),
       passwordInput("clave", "Clave"),
       actionButton("btn_login", "Entrar", class = "btn-primary"),
       uiOutput("error_login"),
       if (CLAVE_ADMIN == "")
         p(class = "text-danger small mt-2",
           "Modo de prueba: no hay ENCUESTA_CLAVE_ADMIN configurada; la clave es 'prueba'."))
}

panel_resultados <- function(catalogos) {
  layout_sidebar(
    sidebar = sidebar(width = 300,
      dateRangeInput("f_fechas", "Fecha de la actividad",
                     start = Sys.Date() - 365, end = Sys.Date() + 180,
                     language = "es", separator = "a", format = "dd-mm-yyyy"),
      selectizeInput("f_colegio", "Colegio", multiple = TRUE,
                     choices = setNames(catalogos$colegios$rbd, catalogos$colegios$colegio),
                     options = list(placeholder = "Todos")),
      checkboxGroupInput("f_curso", "Curso", choices = catalogos$cursos$curso,
                         selected = catalogos$cursos$curso),
      selectInput("f_carrera", "Carrera de interés",
                  choices = c("Todas", catalogos$carreras$carrera)),
      radioButtons("f_contacto", "Contacto",
                   choices = c("Todos", "Solo autorizados para contacto")),
      actionButton("btn_actualizar", "Actualizar datos", icon = icon("rotate")),
      hr(),
      downloadButton("descargar_excel", "Descargar Excel", class = "btn-success")
    ),
    layout_columns(fill = FALSE,
      value_box("Respuestas", textOutput("kpi_respuestas"), theme = "primary"),
      value_box("Con interés en alguna carrera", textOutput("kpi_interesados")),
      value_box("Contactos autorizados", textOutput("kpi_contactos")),
      value_box("Nota promedio de la charla", textOutput("kpi_nota"))
    ),
    layout_columns(
      card(card_header("Menciones por carrera"), plotOutput("g_carreras", height = 380)),
      card(card_header("Evaluación de la charla (promedio 1 a 7)"),
           plotOutput("g_evaluacion", height = 380))
    ),
    navset_card_tab(
      nav_panel("Contactos autorizados", DT::DTOutput("tabla_contactos")),
      nav_panel("Todas las respuestas", DT::DTOutput("tabla_respuestas"))
    )
  )
}

acerca_de_ui <- function(catalogos) {
  info <- catalogos$info
  card(card_body(
    h3("Acerca de esta aplicación"),
    p(strong("Qué resuelve. "), "Reemplaza la encuesta en papel de las charlas en",
      "colegios: los estudiantes responden en una tablet y Admisión obtiene una",
      "planilla con una fila por respuesta, sin digitar."),
    p(strong("Quién la usa. "), "Estudiantes de enseñanza media al final de cada",
      "charla (vista encuesta) y el equipo de Admisión para revisar resultados y",
      "contactos (vista resultados, con clave)."),
    h5("Fuentes de datos"),
    tags$ul(
      tags$li("Respuestas: encuesta de charlas recogida con esta aplicación (año en curso)."),
      tags$li("Catálogo de carreras: ", info$fuente_carreras, "."),
      tags$li("Colegios: ", info$fuente_colegios, "."),
      tags$li("Catálogos generados el ", info$generado, ".")),
    h5("Advertencias de interpretación"),
    tags$ul(
      tags$li("Una persona puede marcar varias carreras: las menciones no son personas."),
      tags$li("Las respuestas son de quienes asistieron y quisieron responder; no",
              "representan a todo el colegio."),
      tags$li("La escala 1 a 7 y la redacción de las preguntas están pendientes de",
              "validación con la encuesta vigente de Admisión."),
      tags$li("Los datos de contacto son personales: úsalos solo para lo autorizado",
              "y no los compartas fuera de Admisión.")),
    p(class = "text-muted small", "Versión ", APP_VERSION, " · almacenamiento: ", BACKEND)
  ))
}

# ---- Cálculos (funciones puras) ---------------------------------------------
preparar_respuestas <- function(dt) {
  dt <- data.table::copy(dt)
  dt[, fecha_actividad := as.Date(fecha_actividad)]
  for (v in c("eval_relator", "eval_claridad", "eval_apoyos", "n_carreras"))
    dt[, (v) := suppressWarnings(as.numeric(get(v)))]
  dt
}

a_menciones <- function(dt) {
  if (nrow(dt) == 0) return(data.table::data.table(id_envio = character(), carrera = character()))
  m <- dt[!is.na(carreras) & carreras != "",
          .(carrera = trimws(unlist(strsplit(carreras, ";", fixed = TRUE)))),
          by = id_envio]
  m[carrera != ""]
}

# ---- Servidor de resultados --------------------------------------------------
resultados_server <- function(input, output, session, catalogos) {
  autenticado <- reactiveVal(FALSE)
  clave_valida <- if (CLAVE_ADMIN == "") "prueba" else CLAVE_ADMIN

  # Los paneles están en la UI, pero ocultos y SIN datos hasta entrar con la clave:
  # todas las salidas dependen de respuestas(), que exige autenticado().
  output$autenticado <- reactive(autenticado())
  outputOptions(output, "autenticado", suspendWhenHidden = FALSE)
  output$error_login <- renderUI(NULL)
  observeEvent(input$btn_login, {
    if (identical(input$clave, clave_valida)) autenticado(TRUE)
    else output$error_login <- renderUI(p(class = "text-danger mt-2", "Clave incorrecta."))
  })

  # Lectura: una sola vez por clic en "Actualizar" (y al entrar)
  respuestas <- eventReactive(list(autenticado(), input$btn_actualizar), {
    req(autenticado())
    tryCatch(preparar_respuestas(leer_respuestas()),
             error = function(e) {
               showNotification(paste("No se pudieron leer las respuestas:",
                                      conditionMessage(e)), type = "error", duration = 10)
               preparar_respuestas(leer_respuestas_vacia())
             })
  }, ignoreNULL = FALSE)

  # Un solo reactive con los filtros: lo usan TODAS las salidas
  filtradas <- reactive({
    dt <- respuestas()
    req(input$f_fechas)
    dt <- dt[is.na(fecha_actividad) |
               (fecha_actividad >= input$f_fechas[1] & fecha_actividad <= input$f_fechas[2])]
    if (length(input$f_colegio)) dt <- dt[rbd %in% input$f_colegio]
    dt <- dt[curso %in% input$f_curso]
    if (!identical(input$f_carrera, "Todas"))
      dt <- dt[id_envio %in% a_menciones(dt)[carrera == input$f_carrera, id_envio]]
    if (identical(input$f_contacto, "Solo autorizados para contacto"))
      dt <- dt[autoriza_contacto == "Sí"]
    dt
  })
  menciones <- reactive(a_menciones(filtradas()))

  hay_datos <- function() validate(need(nrow(filtradas()) > 0,
    "No hay respuestas con estos filtros. Prueba ampliar las fechas o marcar más cursos."))

  output$kpi_respuestas  <- renderText(format(nrow(filtradas()), big.mark = ".", decimal.mark = ","))
  output$kpi_interesados <- renderText(sum(filtradas()$interes_carrera == "Sí", na.rm = TRUE))
  output$kpi_contactos   <- renderText(sum(filtradas()$autoriza_contacto == "Sí", na.rm = TRUE))
  output$kpi_nota <- renderText({
    dt <- filtradas()
    if (nrow(dt) == 0) return("–")
    format(round(mean(c(dt$eval_relator, dt$eval_claridad, dt$eval_apoyos), na.rm = TRUE), 1),
           nsmall = 1, decimal.mark = ",")
  })

  output$g_carreras <- renderPlot({
    hay_datos()
    m <- menciones()
    validate(need(nrow(m) > 0, "Nadie marcó carreras con estos filtros."))
    conteo <- m[, .N, by = carrera]
    ggplot(conteo, aes(x = N, y = reorder(carrera, N))) +
      geom_col(fill = "#00566B") +
      geom_text(aes(label = N), hjust = -0.3, size = 4) +
      scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
      labs(x = "Menciones", y = NULL) + theme_minimal(base_size = 13)
  })

  output$g_evaluacion <- renderPlot({
    hay_datos()
    dt <- filtradas()
    largo <- data.table::melt(dt, id.vars = "id_envio",
                              measure.vars = catalogos$preguntas$id,
                              variable.name = "id", value.name = "nota")
    largo <- merge(largo, catalogos$preguntas[, .(id, texto)], by = "id")
    prom <- largo[, .(promedio = mean(nota, na.rm = TRUE), n = sum(!is.na(nota))), by = texto]
    ggplot(prom, aes(x = promedio, y = stringr_wrap(texto))) +
      geom_col(fill = "#E0A526") +
      geom_text(aes(label = format(round(promedio, 1), decimal.mark = ",")),
                hjust = -0.2, size = 4.5) +
      scale_x_continuous(limits = c(0, 7.5), breaks = 1:7) +
      labs(x = "Promedio (1 a 7)", y = NULL) + theme_minimal(base_size = 13)
  })

  output$tabla_contactos <- DT::renderDT({
    dt <- filtradas()[autoriza_contacto == "Sí",
                      .(Nombre = nombre, Correo = email, Teléfono = telefono,
                        Colegio = colegio, Curso = curso, Carreras = carreras,
                        Fecha = format(fecha_actividad, "%d-%m-%Y"))]
    DT::datatable(dt, rownames = FALSE, options = list(pageLength = 10,
      language = c(DT_ES, emptyTable = "No hay contactos autorizados con estos filtros.")))
  })

  output$tabla_respuestas <- DT::renderDT({
    DT::datatable(filtradas()[, !c("version_autorizacion", "version_app")],
                  rownames = FALSE, options = list(pageLength = 10, scrollX = TRUE,
                  language = c(DT_ES, emptyTable = "No hay respuestas con estos filtros.")))
  })

  output$descargar_excel <- downloadHandler(
    filename = function() paste0("encuesta_charlas_", Sys.Date(), ".xlsx"),
    content = function(file) {
      dt <- filtradas()
      writexl::write_xlsx(list(
        respuestas = dt,
        contactos_autorizados = dt[autoriza_contacto == "Sí"],
        menciones_por_carrera = menciones()[, .(menciones = .N), by = carrera][order(-menciones)]
      ), file)
    }
  )

  # Generador del enlace para la tablet (precarga colegio y fecha)
  output$enlace_tablet <- renderText({
    req(autenticado(), input$enl_rbd, input$enl_fecha)
    cd <- session$clientData
    puerto <- if (nzchar(cd$url_port)) paste0(":", cd$url_port) else ""
    paste0(cd$url_protocol, "//", cd$url_hostname, puerto, cd$url_pathname,
           "?rbd=", input$enl_rbd, "&fecha=", format(input$enl_fecha))
  })
}

panel_enlace <- function(catalogos) {
  card(class = "m-3", card_header("Preparar la tablet para una charla"),
    selectizeInput("enl_rbd", "Colegio",
                   choices = setNames(catalogos$colegios$rbd, catalogos$colegios$colegio)),
    dateInput("enl_fecha", "Fecha de la charla", value = Sys.Date(),
              language = "es", format = "dd-mm-yyyy"),
    p("Abre este enlace en la tablet antes de la charla:"),
    verbatimTextOutput("enlace_tablet"))
}

stringr_wrap <- function(x, ancho = 28)
  vapply(x, function(s) paste(strwrap(s, ancho), collapse = "\n"), character(1))

leer_respuestas_vacia <- function()
  data.table::as.data.table(setNames(replicate(length(COLUMNAS_RESPUESTAS), character(),
                                               simplify = FALSE), COLUMNAS_RESPUESTAS))
