# Introducción a ingesta de datos y Tidyverse
# Renato Vargas

# Limpiar el área de trabajo
rm(list = ls())

# Importar datos

# Valores separados por comas (CSV)
productos_csv <- read.csv(
  "data/intro/productos.csv",
  sep = ",",
  dec = ".",
  encoding = "UTF-8",
  check.names = FALSE # Generalmente es mejor TRUE.
)

# Excel
# llamamos librería
library(readxl)

actividades_economicas <- read_excel(
  "data/intro/productos_y_actividades.xlsx",
  sheet = "actividades"
)

# SPSS o STATA
library(haven)

# Datos ENCUESTA DE NIVELES DE VIDA AÑO 2008

# SPSS
encuesta_hogar <- read_sav("data/intro/02HOGAR.sav")

#STATA
encuesta_vivienda <- read_dta("data/intro/01vivienda.dta")

# Datos Geográficos (no llamamos las librerías)

# Leer el dato geográfico
adm1 <- sf::read_sf("data/intro/gis/gadm41_PAN_1.shp")

# Visualizarlo
ggplot2::ggplot(adm1) +
  ggplot2::geom_sf()

## (Presentación TIDYVERSE)

## Tidyverse (dplyr, tidyr, stringr, etc.)
library(tidyverse)

# Ejemplo de un verbo (Filtrar)
actividades_no_mercado <- actividades_economicas |>
  filter(`Condición de Mercado` == "No de mercado")

# Lo mismo pero anidando para no cometer errores al escribir
actividades_no_mercado <- actividades_economicas |>
  filter(
    `Condición de Mercado` ==
      unique(actividades_economicas$`Condición de Mercado`)[3]
  )


# El "tubo" |>
# También se puede %>%

actividades_limpias2 <- actividades_economicas |>
  mutate(
    Codigo_AE = str_extract(`Código Actividad Económica`, "^\\d+\\.?\\d*")
  ) |>
  select(!`Código Actividad Económica`)


actividades_limpias1 <- actividades_limpias2 |>
  summarize(
    VBP = sum(Producción, na.rm = T),
    CI = sum(`Consumo Intermedio`, na.rm = T),
    VA = sum(`Valor Agregado`, na.rm = T),
    .by = c(
      Codigo_AE,
      `Actividad Económica`,
      # `Condición de Mercado`
    )
  )

actividades_limpias <- actividades_limpias1 |>
  mutate(
    VA_check = VBP - CI
  )

# Guardar a Excel
library(openxlsx)

# Guardar rápidamente
write.xlsx(
  actividades_limpias,
  file = "salidas/actividades_limpias_2018_simple.xlsx",
  asTable = FALSE
)

# Guardar más complejo
ruta_archivo <- "salidas/actividades_limpias_2018_complejo.xlsx"

if (file.exists(ruta_archivo)) {
  # Cargar un libro que ya existe
  wb <- loadWorkbook(ruta_archivo)
} else {
  # Crear uno nuevo si no existe
  wb <- createWorkbook()
}

if ("limpio" %in% names(wb)) {
  removeWorksheet(wb, "limpio")
}
addWorksheet(wb, "limpio")

# Poner los datos en ella
writeData(wb, "limpio", actividades_limpias)
saveWorkbook(wb, ruta_archivo, overwrite = TRUE)
