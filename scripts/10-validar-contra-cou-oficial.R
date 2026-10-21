# Validación: ¿la base procesada es consistente con los COU oficiales?
# Compara salidas/pan_scn_oficial.RDS contra data/cou_oficial celda por celda
# (producto x actividad/transacción) y en agregados macroeconómicos.
# Renato Vargas

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)

rm(list = ls())
source("scripts/00-funciones.R")

# Paso 1. Leer los COU oficiales ----------------------------------------------
archivos <- tibble(
  ruta = list.files("data/cou_oficial", full.names = TRUE, pattern = "xlsx$")
) |>
  mutate(Anio = as.integer(str_extract(basename(ruta), "20\\d{2}(?=\\.xlsx)")))

oficial <- map2(archivos$ruta, archivos$Anio, leer_cou_oficial) |>
  bind_rows()

# Paso 2. Leer la base procesada ----------------------------------------------
base <- readRDS("salidas/pan_scn_oficial.RDS")

# Paso 3. Poner ambas en la misma llave y comparar celda por celda -------------
comparacion <- armonizar_llaves(oficial, base) |>
  mutate(concepto = concepto_macro(Clave, Cuadro))

# Celdas que difieren (más de 1e-6 millones de B/.), por año y cuadro
comparacion |>
  summarize(
    celdas = n(),
    celdas_distintas = sum(abs(diferencia) > 1e-6),
    diferencia_maxima = max(abs(diferencia)),
    .by = c(Anio, Cuadro)
  ) |>
  arrange(Anio, Cuadro)

# Paso 4. Agregados macroeconómicos --------------------------------------------
agregados <- comparacion |>
  summarize(
    oficial = sum(oficial),
    nueva = sum(nueva),
    .by = c(Anio, concepto)
  ) |>
  mutate(
    diferencia = nueva - oficial,
    diferencia_pct = diferencia / oficial * 100
  )

agregados |>
  filter(concepto != "Márgenes", concepto != "Ajuste CIF/FOB") |>
  arrange(concepto, Anio)

# Paso 5. Valor agregado bruto (fila B.1b del cuadro de Utilización) -----------
vab_oficial <- map2(archivos$ruta, archivos$Anio, \(ruta, anio) {
  x <- read_excel(
    ruta, sheet = "Utilización", col_names = FALSE,
    col_types = "text", .name_repair = "minimal"
  )
  codigos <- unlist(x[10, ])
  valores <- suppressWarnings(as.numeric(unlist(x[210, ])))
  es_actividad <- !is.na(codigos) & str_detect(codigos, "^\\d+\\.\\d+")
  tibble(Anio = anio, VAB_oficial = sum(valores[es_actividad], na.rm = TRUE))
}) |>
  bind_rows()

vab_nueva <- base |>
  filter(Cuadro == "03 Valor Agregado") |>
  mutate(Anio = as.integer(`Año`)) |>
  summarize(VAB_nueva = sum(Valor), .by = Anio)

vab <- vab_oficial |>
  left_join(vab_nueva, by = "Anio") |>
  mutate(diferencia = VAB_nueva - VAB_oficial) |>
  arrange(Anio)

vab

# Paso 6. Coherencia interna de la base ----------------------------------------
# a) Oferta total = Utilización total por año
base |>
  filter(Cuadro != "03 Valor Agregado") |>
  summarize(total = sum(Valor), .by = c(`Año`, Cuadro)) |>
  pivot_wider(names_from = Cuadro, values_from = total) |>
  mutate(diferencia = `01 Oferta` - `02 Utilización`)

# b) VAB = Producción - Consumo intermedio, por actividad y condición
base |>
  filter(`Código área transaccional columnas` == "ATC01") |>
  summarize(
    v = sum(Valor),
    .by = c(`Año`, Cuadro, `Código Clasificación Actividades`, `Condición de Mercado`)
  ) |>
  pivot_wider(names_from = Cuadro, values_from = v, values_fill = 0) |>
  mutate(diferencia = `01 Oferta` - `02 Utilización` - `03 Valor Agregado`) |>
  summarize(diferencia_maxima = max(abs(diferencia)), .by = `Año`)
