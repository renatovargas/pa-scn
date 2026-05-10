# Script de procesamiento COU con funciones
# Renato Vargas

# Librerías
library(readxl) # Importar datos de Excel
library(dplyr) # Manipulación de datos
library(tidyr) # Limpieza de datos
library(stringr) # Manipulación de textos
library(openxlsx) # Exportación a Excel
# library(arrow)

# Limpiar el área de trabajo
rm(list = ls())

# Cargamos herramientas
source("scripts/00-funciones.R")
iso3 <- "pan"

# Rutas
ruta_config <- "data/config"
salida_rds <- "salidas/pan_bioeconomia.RDS"
salida_xlsx <- "salidas/pan_bioeconomia.xlsx"
ruta_datos <- "data/cou"

# Cargar config
config <- cargar_config(
  iso3 = iso3,
  ruta_config = "data/config"
)


# Ahora usamos nuestra función para procesar todos los cuadrantes
# de manera iterativa

cuadrantes <- lapply(seq_len(nrow(config)), function(i) {
  procesar_cuadrante(
    iso3 = config$iso3[i],
    anio = config$anio[i],
    v_equivalencias = config$v_equivalencias[i],
    codigo_cuadrante = config$codigo_cuadrante[i],
    cuadrante = config$cuadrante[i],
    archivo = file.path("data/cou", config$archivo[i]),
    hoja = config$hoja[i],
    cuadro = config$cuadro[i],
    rango = config$rango[i],
    excluir_filas = procesar_indices(config$excluir_filas[i]),
    excluir_columnas = procesar_indices(config$excluir_columnas[i]),
    unidad = config$unidad[i],
    precios = config$precios[i]
  )
})


# Inspeccionamos la lista resultante
cuadrantes

# Y los unimos en un solo objeto

pan_scn <- bind_rows(cuadrantes)

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
pan_scn <- left_join(pan_scn, clasificacionColumnas, by = "Columnas")
pan_scn <- left_join(pan_scn, clasificacionFilas, by = "Filas")


library(tidyverse)

pan_scn_xl <- pan_scn |>
  mutate(
    across(
      everything(),
      ~ ifelse(. == "" | is.na(.), "-", .)
    )
  )

# Y lo exportamos a Excel
write.xlsx(
  pan_scn_xl,
  "salidas/pan_scn.xlsx",
  sheetName = "PAN_SCN_BD",
  colNames = TRUE,
  rowNames = FALSE,
  overwrite = TRUE
)


# Toda la base de datos en RDS
# Formato binario de R que ocupa muy poco espacio en disco
saveRDS(pan_scn, file = "salidas/pan_scn.RDS")
