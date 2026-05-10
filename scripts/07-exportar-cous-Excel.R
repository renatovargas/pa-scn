# Generar COU agregado y exportar a Excel
# Renato Vargas

# Cargamos los paquetes necesarios
library(tidyverse)
library(openxlsx)

# Limpiamos el área de trabajo
rm(list = ls())

# Cargamos nuestros datos procesados
pan_scn <- readRDS("salidas/pan_scn.RDS")

# COU resumido de la Bioeconomía
library(dplyr)
library(tidyr)
library(stringr)

bio_pivot <- pan_scn |>
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

      # Columnas simples
      str_squish(paste(
        str_pad(`Código transacciones agregadas`, 2, pad = "0"),
        `Transacciones agregadas`
      )),

      # Columnas jerárquicas
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
  filter(Año == 2022) |>
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

# Limpiamos nombres de columna
names(bio_pivot) <- names(bio_pivot) |>
  str_replace_all("\\n+$", "")

# Exportamos a Excel
# ==================

# Crear workbook
wb <- createWorkbook()

# Crear hoja
addWorksheet(wb, "COU BIO 2022")

# Filas clave
fila_inicio <- 8
fila_header <- fila_inicio
fila_datos <- fila_inicio + 1

# Escribir títulos
writeData(
  wb,
  "COU BIO 2022",
  "SISTEMA DE CUENTAS NACIONALES DE PANAMÁ",
  startRow = 1,
  startCol = 1
)

writeData(
  wb,
  "COU BIO 2022",
  "CUADRO DE OFERTA Y UTILIZACIÓN BIOECONÓMICO AGREGADO",
  startRow = 2,
  startCol = 1
)

writeData(
  wb,
  "COU BIO 2022",
  "OFERTA Y UTILIZACIÓN DE PRODUCTOS A PRECIOS DE COMPRADOR",
  startRow = 3,
  startCol = 1
)

writeData(wb, "COU BIO 2022", "AÑO 2022", startRow = 4, startCol = 1)

writeData(
  wb,
  "COU BIO 2022",
  "(en millones de B/.)",
  startRow = 5,
  startCol = 1
)

# Escribir datos
writeData(
  wb,
  sheet = "COU BIO 2022",
  x = bio_pivot,
  startRow = fila_inicio,
  startCol = 1,
  borders = "surrounding"
)

# Estilos
title_style <- createStyle(
  fontSize = 12,
  textDecoration = "bold"
)

header_style <- createStyle(
  fontSize = 10,
  textDecoration = "bold",
  halign = "center",
  valign = "center",
  fgFill = "#D9EAF7",
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

# Dimensiones
n_rows <- nrow(bio_pivot) + fila_inicio
n_cols <- ncol(bio_pivot)

# Aplicar estilos
# ===============

# Títulos
addStyle(
  wb,
  sheet = "COU BIO 2022",
  style = title_style,
  rows = 1:5,
  cols = 1,
  gridExpand = TRUE
)

# Encabezado
addStyle(
  wb,
  sheet = "COU BIO 2022",
  style = header_style,
  rows = fila_header,
  cols = 1:n_cols,
  gridExpand = TRUE
)

# Campos de fila
addStyle(
  wb,
  sheet = "COU BIO 2022",
  style = row_field_style,
  rows = fila_datos:n_rows,
  cols = 1:4,
  gridExpand = TRUE,
  stack = TRUE
)

# Valores
addStyle(
  wb,
  sheet = "COU BIO 2022",
  style = number_style,
  rows = fila_datos:n_rows,
  cols = 5:n_cols,
  gridExpand = TRUE,
  stack = TRUE
)

# Total
addStyle(
  wb,
  sheet = "COU BIO 2022",
  style = total_style,
  rows = fila_datos:n_rows,
  cols = n_cols,
  gridExpand = TRUE,
  stack = TRUE
)

# Bordes exteriores
# =================

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

# Borde exterior del encabezado
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = fila_header,
  cols = 1:n_cols
)

# Bordes exteriores por Cuadro
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = 9:24,
  cols = 1:n_cols
)

agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = 25:40,
  cols = 1:n_cols
)

agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = 41,
  cols = 1:n_cols
)

# Bordes exteriores verticales
# ============================

# Campos de filas
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = fila_header:n_rows,
  cols = 1:4
)

# 01 Bioeconomía
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = fila_header:n_rows,
  cols = 5:6
)

# 02 Bioeconomía extendida
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = fila_header:n_rows,
  cols = 7:8
)

# 03 No bioeconomía
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = fila_header:n_rows,
  cols = 9:11
)

# Demanda final
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = fila_header:n_rows,
  cols = 12:19
)

# Total
agregar_borde_exterior(
  wb,
  sheet = "COU BIO 2022",
  filas = fila_header:n_rows,
  cols = 20
)

# Anchos de columnas
# Cuadro
setColWidths(
  wb,
  "COU BIO 2022",
  cols = 1,
  widths = 14
)

# Resto de campos de fila
setColWidths(
  wb,
  "COU BIO 2022",
  cols = 2:4,
  widths = "auto"
)
setColWidths(wb, "COU BIO 2022", cols = 5:n_cols, widths = 17)

# Altura del encabezado
setRowHeights(
  wb,
  "COU BIO 2022",
  rows = fila_header,
  heights = 108
)

# Guardar
saveWorkbook(
  wb,
  file = "salidas/cou_bioeconomia_agregado_2022.xlsx",
  overwrite = TRUE
)
