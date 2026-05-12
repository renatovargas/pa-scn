library(readxl) # Importar datos de Excel
library(dplyr) # Manipulación de datos
library(tidyr) # Limpieza de datos
library(stringr) # Manipulación de textos
library(openxlsx) # Exportación a Excel
# library(arrow)

# Limpiar el área de trabajo
rm(list = ls())

# Cargamos herramientas
source("scripts/00-funciones-exportar-Excel.R")

# Cargamos nuestros datos procesados
pan_scn <- readRDS("salidas/pan_scn.RDS")

# Exportamos a Excel
# ==================

wb <- createWorkbook()

anios <- pan_scn |>
  distinct(Año) |>
  arrange(Año) |>
  pull(Año)

anio_min <- min(anios)
anio_max <- max(anios)

# Nombre de archivo a la medida
archivo_salida <- paste0(
  "salidas/COU-BIO-agregado-",
  anio_min,
  "-",
  anio_max,
  ".xlsx"
)

for (anio in anios) {
  crear_hoja_cou_bio(
    wb = wb,
    datos = pan_scn,
    anio = anio
  )
}

saveWorkbook(
  wb,
  file = archivo_salida,
  overwrite = TRUE
)
