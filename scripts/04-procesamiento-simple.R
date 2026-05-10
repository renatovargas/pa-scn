# Script de procesamiento COU sin funciones
# Renato Vargas

# Librerías (la mayoría se puede cargar con tidyverse)
library(readxl) # Importar datos de Excel
library(dplyr) # Manipulación de datos
library(tidyr) # Limpieza de datos
library(stringr) # Manipulación de textos
library(openxlsx) # Exportación a Excel

# Limpiar el área de trabajo
rm(list = ls())

# País
iso3 = "pan"

# Versión de Tabla de Equivalencias
v_equivalencias = "v02"

# Datos
anio <- 2018
archivo <- "data/cou/PAN_COU_Corr_2018.xlsx"
precios <- "Corrientes"
unidad <- "millones de B/."

# Hojas del Excel
hojas_todas <- excel_sheets(archivo)

# Datos de interés:
# Oferta

codigo_cuadrante <- "q01"
cuadro <- "01 Oferta"
hoja <- hojas_todas[1]
rango <- "C12:DF208"

excluir_columnas <- c(75, 79, 90, 91, 92, 93, 96, 98, 103, 107, 108)
excluir_filas <- c(189, 191, 196, 197)

# Importar el cuerpo de datos
datos1 <- read_excel(
  archivo,
  range = paste0("'", hoja, "'!", rango),
  col_names = FALSE,
  col_types = "numeric"
)

# Crear correlativos de fila y columna estables
n_filas <- nrow(datos1)
n_columnas <- ncol(datos1)
cod_filas <- sprintf(
  "%s_%s_%s_f%04d",
  iso3,
  v_equivalencias,
  codigo_cuadrante,
  seq_len(n_filas)
)
cod_columnas <- sprintf(
  "%s_%s_%s_c%04d",
  iso3,
  v_equivalencias,
  codigo_cuadrante,
  seq_len(n_columnas)
)

# Reemplazar las celdas vacías con ceros
datos2 <- datos1 |>
  mutate(
    across(
      everything(),
      ~ replace_na(.x, 0)
    )
  ) |>
  setNames(cod_columnas) |>
  mutate(
    Filas = cod_filas,
    .before = 1
  )

# Deshacernos de filas y columnas redundantes o vacías
if (length(excluir_filas) > 0) {
  datos3 <- datos2[-excluir_filas, , drop = FALSE]
}

if (length(excluir_columnas) > 0) {
  # Puesto que agregamos una columna de nombres al inicio
  # debemos correr las columnas a excluir por una posición
  # lo que se logra con (exlcuir_columnas + 1) abajo.
  # Otra forma de hacerlo sería quitar el .before = 1 en
  # la línaea 77 en el último mutate() de arriba para que
  # quede al final y no modifique las posiciones, pero esto
  # funciona bien.
  datos4 <- datos3[, -(excluir_columnas + 1), drop = FALSE]
}

# Alargar Y agregar columnas informativas
datos5 <- datos4 |>
  pivot_longer(
    cols = -Filas,
    names_to = "Columnas",
    values_to = "Valor"
  ) |>
  mutate(
    Filas,
    Columnas,
    `Año` = anio,
    Cuadro = cuadro,
    Cuadrante = codigo_cuadrante,
    Unidades = unidad,
    Precios = precios,
    Valor,
    .keep = "none" # Lo mismo que si usamos transmute.
  )

# Finalmente damos valor a las filas y columnas

#Le damos significado a las filas y columnas
clasificacionColumnas <- read_xlsx(
  "data/config/pan_v02_equivalencias.xlsx",
  sheet = "columnas",
  col_names = TRUE,
)
clasificacionFilas <- read_xlsx(
  "data/config/pan_v02_equivalencias.xlsx",
  sheet = "filas",
  col_names = TRUE,
)

# Hacemos una unión
datos6 <- left_join(datos5, clasificacionColumnas, by = "Columnas")
pan_oferta_2018 <- left_join(datos6, clasificacionFilas, by = "Filas")

# Y guardamos a Excel
# Guardar rápidamente
write.xlsx(
  pan_oferta_2018,
  file = "salidas/pan_oferta_2018.xlsx",
  asTable = FALSE
)
