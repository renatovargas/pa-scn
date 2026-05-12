# Funciones para procesar Cuadros de Oferta y Utilización
# Renato Vargas

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)
library(openxlsx)

# Función para exportar un COU BIO agregado a Excel
# =================================================

crear_hoja_cou_bio <- function(wb, datos, anio) {
  hoja <- paste0("COU BIO ", anio)

  bio_pivot <- datos |>
    mutate(
      across(
        everything(),
        ~ ifelse(. == "" | is.na(.), "", .)
      ),

      `Área Filas` = str_squish(paste(
        `Áreas Transaccionales Filas No.`,
        `Áreas Transaccionales Filas Descripción`
      )),

      `Bioeconomía Productos` = if_else(
        `Código Bioeconomía Productos` == "",
        "",
        str_squish(paste(
          `Código Bioeconomía Productos`,
          `Clasificación Bioeconomía Productos`
        ))
      ),

      `Productos agrupados` = if_else(
        `Código Productos Agregados` == "",
        "",
        str_squish(paste(
          str_pad(`Código Productos Agregados`, 2, pad = "0"),
          `Productos Agregados`
        ))
      ),

      `Columna COU` = if_else(
        `Código Bioeconomía Actividades` == "",

        str_squish(paste(
          str_pad(`Código transacciones agregadas`, 2, pad = "0"),
          `Transacciones agregadas`
        )),

        paste(
          str_squish(paste(
            str_pad(`Código transacciones agregadas`, 2, pad = "0"),
            `Transacciones agregadas`
          )),
          str_squish(paste(
            str_pad(`Código Bioeconomía Actividades`, 2, pad = "0"),
            `Bioeconomía Actividades`
          )),
          str_squish(paste(
            `Código Actividades Agregadas`,
            `Actividades Agregadas`
          )),
          sep = "\n\n"
        )
      )
    ) |>
    filter(Año == anio) |>
    arrange(
      Cuadro,
      `Áreas Transaccionales Filas No.`,
      `Código Bioeconomía Productos`,
      `Código Productos Agregados`
    ) |>
    pivot_wider(
      id_cols = c(
        Cuadro,
        `Área Filas`,
        `Bioeconomía Productos`,
        `Productos agrupados`
      ),
      names_from = `Columna COU`,
      values_from = Valor,
      values_fn = sum,
      names_sort = TRUE
    ) |>
    mutate(
      Total = rowSums(
        across(where(is.numeric)),
        na.rm = TRUE
      )
    )

  names(bio_pivot) <- names(bio_pivot) |>
    str_replace_all("\\n+$", "")

  # Esta parte nos crea las filas de subtotales de oferta y utilización
  # ===================================================================

  columnas_numericas <- names(bio_pivot)[sapply(bio_pivot, is.numeric)]

  crear_total_cuadro <- function(df, cuadro, etiqueta) {
    df |>
      filter(Cuadro == cuadro) |>
      summarise(
        across(
          all_of(columnas_numericas),
          ~ sum(.x, na.rm = TRUE)
        )
      ) |>
      mutate(
        Cuadro = cuadro,
        `Área Filas` = etiqueta,
        `Bioeconomía Productos` = "",
        `Productos agrupados` = "",
        .before = 1
      ) |>
      select(names(bio_pivot))
  }

  total_oferta <- crear_total_cuadro(
    bio_pivot,
    cuadro = "01 Oferta",
    etiqueta = "Oferta Total"
  )

  total_utilizacion <- crear_total_cuadro(
    bio_pivot,
    cuadro = "02 Utilización",
    etiqueta = "Utilización Total"
  )

  bio_pivot <- bind_rows(
    bio_pivot |> filter(Cuadro == "01 Oferta"),
    total_oferta,
    bio_pivot |> filter(Cuadro == "02 Utilización"),
    total_utilizacion,
    bio_pivot |> filter(!Cuadro %in% c("01 Oferta", "02 Utilización"))
  )

  addWorksheet(wb, hoja)

  fila_inicio <- 8
  fila_header <- fila_inicio
  fila_datos <- fila_inicio + 1

  writeData(
    wb,
    hoja,
    "SISTEMA DE CUENTAS NACIONALES DE PANAMÁ",
    startRow = 1,
    startCol = 1
  )
  writeData(
    wb,
    hoja,
    "CUADRO DE OFERTA Y UTILIZACIÓN BIOECONÓMICO AGREGADO",
    startRow = 2,
    startCol = 1
  )
  writeData(
    wb,
    hoja,
    "OFERTA Y UTILIZACIÓN DE PRODUCTOS A PRECIOS DE COMPRADOR",
    startRow = 3,
    startCol = 1
  )
  writeData(wb, hoja, paste0("AÑO ", anio), startRow = 4, startCol = 1)
  writeData(wb, hoja, "(en millones de B/.)", startRow = 5, startCol = 1)

  writeData(
    wb,
    sheet = hoja,
    x = bio_pivot,
    startRow = fila_inicio,
    startCol = 1,
    borders = "surrounding"
  )

  title_style <- createStyle(fontSize = 12, textDecoration = "bold")

  header_style_base <- createStyle(
    fontSize = 10,
    textDecoration = "bold",
    halign = "center",
    valign = "center",
    fgFill = "#0f243e",
    fontColour = "white",
    border = "TopBottomLeftRight",
    wrapText = TRUE
  )

  header_style_bio <- createStyle(
    fontSize = 10,
    textDecoration = "bold",
    halign = "center",
    valign = "center",
    fgFill = "#92d050",
    fontColour = "black",
    border = "TopBottomLeftRight",
    wrapText = TRUE
  )

  header_style_bio_ext <- createStyle(
    fontSize = 10,
    textDecoration = "bold",
    halign = "center",
    valign = "center",
    fgFill = "#c5e0b4",
    fontColour = "black",
    border = "TopBottomLeftRight",
    wrapText = TRUE
  )

  header_style_no_bio <- createStyle(
    fontSize = 10,
    textDecoration = "bold",
    halign = "center",
    valign = "center",
    fgFill = "#f4b183",
    fontColour = "black",
    border = "TopBottomLeftRight",
    wrapText = TRUE
  )

  row_field_style <- createStyle(
    fontSize = 10,
    fgFill = "#EAF6FB",
    border = "TopBottomLeftRight"
  )

  number_style <- createStyle(
    fontSize = 10,
    numFmt = "#,##0.00",
    border = "TopBottomLeftRight"
  )

  total_style <- createStyle(
    fontSize = 10,
    textDecoration = "bold",
    numFmt = "#,##0.00",
    border = "TopBottomLeftRight"
  )

  subtotal_style <- createStyle(
    fontSize = 10,
    textDecoration = "bold"
  )

  n_rows <- nrow(bio_pivot) + fila_inicio
  n_cols <- ncol(bio_pivot)

  addStyle(wb, hoja, title_style, rows = 1:5, cols = 1, gridExpand = TRUE)

  # Encabezados base
  addStyle(
    wb,
    hoja,
    header_style_base,
    rows = fila_header,
    cols = c(1:4, 12:n_cols),
    gridExpand = TRUE
  )

  # 01 Bioeconomía
  addStyle(
    wb,
    hoja,
    header_style_bio,
    rows = fila_header,
    cols = 5:6,
    gridExpand = TRUE
  )

  # 02 Bioeconomía extendida
  addStyle(
    wb,
    hoja,
    header_style_bio_ext,
    rows = fila_header,
    cols = 7:8,
    gridExpand = TRUE
  )

  # 03 No bioeconomía
  addStyle(
    wb,
    hoja,
    header_style_no_bio,
    rows = fila_header,
    cols = 9:11,
    gridExpand = TRUE
  )

  addStyle(
    wb,
    hoja,
    row_field_style,
    rows = fila_datos:n_rows,
    cols = 1:4,
    gridExpand = TRUE,
    stack = TRUE
  )

  addStyle(
    wb,
    hoja,
    number_style,
    rows = fila_datos:n_rows,
    cols = 5:n_cols,
    gridExpand = TRUE,
    stack = TRUE
  )

  addStyle(
    wb,
    hoja,
    total_style,
    rows = fila_datos:n_rows,
    cols = n_cols,
    gridExpand = TRUE,
    stack = TRUE
  )

  # Filas de subtotal y valor agregado
  addStyle(
    wb,
    hoja,
    subtotal_style,
    rows = c(25, 42, 43),
    cols = 1:n_cols,
    gridExpand = TRUE,
    stack = TRUE
  )

  borde_sup <- createStyle(border = "top", borderStyle = "thick")
  borde_inf <- createStyle(border = "bottom", borderStyle = "thick")
  borde_izq <- createStyle(border = "left", borderStyle = "thick")
  borde_der <- createStyle(border = "right", borderStyle = "thick")

  agregar_borde_exterior <- function(wb, sheet, filas, cols) {
    addStyle(
      wb,
      sheet,
      borde_sup,
      rows = min(filas),
      cols = cols,
      gridExpand = TRUE,
      stack = TRUE
    )
    addStyle(
      wb,
      sheet,
      borde_inf,
      rows = max(filas),
      cols = cols,
      gridExpand = TRUE,
      stack = TRUE
    )
    addStyle(
      wb,
      sheet,
      borde_izq,
      rows = filas,
      cols = min(cols),
      gridExpand = TRUE,
      stack = TRUE
    )
    addStyle(
      wb,
      sheet,
      borde_der,
      rows = filas,
      cols = max(cols),
      gridExpand = TRUE,
      stack = TRUE
    )
  }

  agregar_borde_exterior(wb, hoja, filas = fila_header, cols = 1:n_cols)

  agregar_borde_exterior(wb, hoja, filas = 9:25, cols = 1:n_cols)
  agregar_borde_exterior(wb, hoja, filas = 26:42, cols = 1:n_cols)
  agregar_borde_exterior(wb, hoja, filas = 43, cols = 1:n_cols)
  # Bordes para filas de totales
  agregar_borde_exterior(
    wb,
    hoja,
    filas = 25,
    cols = 1:n_cols
  )
  agregar_borde_exterior(
    wb,
    hoja,
    filas = 42,
    cols = 1:n_cols
  )

  agregar_borde_exterior(wb, hoja, filas = fila_header:n_rows, cols = 1:4)
  agregar_borde_exterior(wb, hoja, filas = fila_header:n_rows, cols = 5:6)
  agregar_borde_exterior(wb, hoja, filas = fila_header:n_rows, cols = 7:8)
  agregar_borde_exterior(wb, hoja, filas = fila_header:n_rows, cols = 9:11)
  agregar_borde_exterior(wb, hoja, filas = fila_header:n_rows, cols = 12:19)
  agregar_borde_exterior(wb, hoja, filas = fila_header:n_rows, cols = 20)

  setColWidths(wb, hoja, cols = 1, widths = 14)
  setColWidths(wb, hoja, cols = 2:4, widths = "auto")
  setColWidths(wb, hoja, cols = 5:n_cols, widths = 17)

  setRowHeights(
    wb,
    hoja,
    rows = fila_header,
    heights = 108
  )

  invisible(wb)
}
