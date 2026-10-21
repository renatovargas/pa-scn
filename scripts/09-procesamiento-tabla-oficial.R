# Procesamiento de la Tabla plana oficial (cuadros complementarios 2018-2024)
# Genera una base de datos con el mismo esquema que salidas/pan_scn.RDS
# Requiere haber corrido antes scripts/09a-crear-equivalencias-v03.R
# Renato Vargas

# Librerías
library(readxl) # Importar datos de Excel
library(dplyr) # Manipulación de datos
library(tidyr) # Limpieza de datos
library(stringr) # Manipulación de textos
library(openxlsx) # Exportación a Excel

# Limpiar el área de trabajo
rm(list = ls())

# Cargamos herramientas
source("scripts/00-funciones.R")

# Rutas ------------------------------------------------------------------------
ruta_tabla <- "data/cou_flat/P0705547520260930134459Cuadros complementarios a precios corrientes años 2018-24.xlsx"
ruta_equiv <- "data/config/pan_v03_equivalencias.xlsx"

# Paso 1. Leer la Tabla y las equivalencias ------------------------------------
tabla <- leer_tabla_oficial(ruta_tabla)

equiv_cuadrantes <- read_xlsx(ruta_equiv, sheet = "cuadrantes")
equiv_transacciones <- read_xlsx(ruta_equiv, sheet = "transacciones")
equiv_filas <- read_xlsx(ruta_equiv, sheet = "filas")
equiv_columnas <- read_xlsx(ruta_equiv, sheet = "columnas")

# Paso 2. Revisar qué años trae la Tabla ---------------------------------------
# 2025 (E) trae solo unas pocas filas (no es un cuadro completo), así que se
# deja fuera. 2024 (P) es provisional y se conserva con su Estatus.
tabla |>
  count(Anio, Estatus)

tabla <- tabla |>
  filter(Anio <= 2024)

# Paso 3. Controlar que los totales oficiales cuadran con sus componentes ------
# Se hace ANTES de eliminar las sumas parciales: P001 = P00101 + P00102 + P00103,
# etc. Si devuelve filas, hay diferencias entre un total y sus partes.
verificar_totales(tabla)

# Paso 4. Separar el código de actividad y su sufijo (M, NM, UFP) --------------
tabla <- separar_actividad(tabla)

# Paso 5. Quedarnos solo con datos individuales --------------------------------
# Sin totales, sin filas de "total de la actividad" (Idf_Producto "00"),
# sin series que no son corrientes ni variables fuera del SCN.
datos <- filtrar_datos_individuales(tabla, equiv_transacciones)

# Cuántas filas quedaron por transacción
datos |>
  count(Idf_Transaccion, codigo_cuadrante)

# Paso 5b. Recuperar márgenes y ajuste CIF/FOB ---------------------------------
# La Tabla no los trae; se obtienen por identidad oferta = utilización.
ajustes <- derivar_ajustes_oferta(datos, equiv_transacciones)

# Los márgenes deben sumar cero (solo redistribuyen entre productos).
ajustes |>
  summarize(neto = sum(Valor), .by = c(Anio, Idf_Transaccion))

datos <- bind_rows(datos, ajustes)

# Paso 6. Unir las clasificaciones ---------------------------------------------
# Las llaves son los códigos de la Tabla (transacción, actividad y producto).
# No dependemos de la posición en el Excel.
datos <- agregar_clasificaciones(datos, equiv_columnas, equiv_filas)

# Paso 7. Controles de mapeo ---------------------------------------------------
# Debe devolver cero filas: toda combinación de la Tabla tiene fila y columna.
reportar_sin_mapear(datos)

# El sufijo M / NM / UFP debe coincidir con la Condición de Mercado.
verificar_condicion_mercado(datos)

# Paso 8. Completar los cuadros y armar el esquema de pan_scn ------------------
# La Tabla solo trae celdas distintas de cero. Se completa la rejilla de
# filas x columnas con ceros para que los cuadros queden rectangulares.
datos <- completar_cuadrantes(
  datos,
  equiv_filas,
  equiv_columnas,
  equiv_cuadrantes
)

pan_scn_oficial <- armar_esquema_pan_scn(datos)

pan_scn_oficial

# Paso 9. Control contra la base anterior (2018-2021) --------------------------
# Las dos fuentes no son idénticas (revisiones y apertura de la construcción
# 36.1 / 36.2 / 36.3), así que se compara por producto y cuadro, sumando las
# actividades de construcción.
pan_scn_anterior <- readRDS("salidas/pan_scn.RDS")

comparacion <- bind_rows(
  nueva = pan_scn_oficial,
  anterior = pan_scn_anterior,
  .id = "fuente"
) |>
  filter(`Año` <= 2021, Cuadro != "03 Valor Agregado") |>
  summarize(
    total = sum(Valor),
    .by = c(fuente, `Año`, Cuadro, `Código área transaccional columnas`)
  ) |>
  pivot_wider(names_from = fuente, values_from = total) |>
  mutate(diferencia = nueva - anterior)

comparacion

# Paso 10. Exportar ------------------------------------------------------------
pan_scn_xl <- pan_scn_oficial |>
  mutate(
    across(
      everything(),
      ~ ifelse(. == "" | is.na(.), "-", .)
    )
  )

write.xlsx(
  pan_scn_xl,
  "salidas/pan_scn_oficial.xlsx",
  sheetName = "PAN_SCN_BD",
  colNames = TRUE,
  rowNames = FALSE,
  overwrite = TRUE
)

saveRDS(pan_scn_oficial, file = "salidas/pan_scn_oficial.RDS")

library(DBI)
library(duckdb)

con <- dbConnect(duckdb(), dbdir = "salidas/pan_scn.duckdb")

dbWriteTable(
  con,
  name = "pan_scn_oficial",
  value = as.data.frame(pan_scn_oficial),
  overwrite = TRUE
)

dbDisconnect(con, shutdown = TRUE)
