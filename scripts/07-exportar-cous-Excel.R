# Generar COU agregado y exportar a Excel
# Renato Vargas

# Leemos nuestros datos procesados
library(tidyverse)
library(openxlsx)

# Limpiamos el área de trabajo
rm(list = ls())

# Cargamos nuestros datos
pan_scn <- readRDS("salidas/pan_scn.RDS")

# COU resumido de la Bioeconomía
library(dplyr)
library(tidyr)
library(stringr)

bio_pivot <- pan_scn |>
  filter(Año == 2022) |>

  # Orden jerárquico de filas
  arrange(
    Cuadro,
    `Áreas Transaccionales Filas No.`,
    `Código Bioeconomía Productos`,
    `Código Productos Agregados`
  ) |>

  # Pivotear
  pivot_wider(
    # Filas
    id_cols = c(
      Cuadro,
      `Áreas Transaccionales Filas No.`,
      `Áreas Transaccionales Filas Descripción`,
      `Código Bioeconomía Productos`,
      `Clasificación Bioeconomía Productos`,
      `Código Productos Agregados`,
      `Productos Agregados`
    ),

    # Columnas
    names_from = c(
      `Código transacciones agregadas`,
      `Transacciones agregadas`,
      `Código Bioeconomía Actividades`,
      `Bioeconomía Actividades`,
      `Código Actividades Agregadas`,
      `Actividades Agregadas`
    ),

    # Nombres de columnas con padding
    names_glue = "{str_pad(`Código transacciones agregadas`, 2, pad = '0')} {`Transacciones agregadas`}\n\n{str_pad(`Código Bioeconomía Actividades`, 2, pad = '0')} {`Bioeconomía Actividades`}\n\n{`Código Actividades Agregadas`} {`Actividades Agregadas`}",

    values_from = Valor,

    values_fn = sum,

    names_sort = TRUE
  ) |>

  # Total por fila
  mutate(
    Total = rowSums(
      across(where(is.numeric)),
      na.rm = TRUE
    )
  )

bio_pivot <- bio_pivot |>
  mutate(
    across(
      c(
        `Código Bioeconomía Productos`,
        `Clasificación Bioeconomía Productos`,
        `Código Productos Agregados`,
        `Productos Agregados`
      ),
      ~ replace_na(as.character(.x), "")
    )
  )

names(bio_pivot) <- names(bio_pivot) |>
  str_replace_all("\\n\\nNA NA\\n\\nNA NA$", "")
# Cambiar separador de columnas a pipe + salto de línea
# str_replace_all(" \\| ", " |\n")

# Exportamos a Excel

library(openxlsx)

# Crear workbook
wb <- createWorkbook()

# Crear hoja
addWorksheet(wb, "sut_bioeconomia")

# Escribir datos
writeData(
  wb,
  sheet = "sut_bioeconomia",
  x = bio_pivot,
  startRow = 1,
  startCol = 1,
  borders = "surrounding"
)

# Congelar encabezados y campos de fila
# freezePane(
#   wb,
#   sheet = "sut_bioeconomia",
#   firstActiveRow = 2,
#   firstActiveCol = 8
# )

# Estilos
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
n_rows <- nrow(bio_pivot) + 1
n_cols <- ncol(bio_pivot)

# Aplicar estilos
addStyle(
  wb,
  sheet = "sut_bioeconomia",
  style = header_style,
  rows = 1,
  cols = 1:n_cols,
  gridExpand = TRUE
)

addStyle(
  wb,
  sheet = "sut_bioeconomia",
  style = row_field_style,
  rows = 2:n_rows,
  cols = 1:7,
  gridExpand = TRUE,
  stack = TRUE
)

addStyle(
  wb,
  sheet = "sut_bioeconomia",
  style = number_style,
  rows = 2:n_rows,
  cols = 8:n_cols,
  gridExpand = TRUE,
  stack = TRUE
)

addStyle(
  wb,
  sheet = "sut_bioeconomia",
  style = total_style,
  rows = 2:n_rows,
  cols = n_cols,
  gridExpand = TRUE,
  stack = TRUE
)

# Anchos de columnas
setColWidths(wb, "sut_bioeconomia", cols = 1:7, widths = "auto")
setColWidths(wb, "sut_bioeconomia", cols = 8:n_cols, widths = 14)

# Altura del encabezado
setRowHeights(
  wb,
  "sut_bioeconomia",
  rows = 1,
  heights = 94
)

# Filtro simple
addFilter(wb, "sut_bioeconomia", rows = 1, cols = 1:n_cols)

# Guardar
saveWorkbook(
  wb,
  file = "salidas/cou_bioeconomia_agregado_2022.xlsx",
  overwrite = TRUE
)
