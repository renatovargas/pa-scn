# Crea data/config/pan_v03_equivalencias.xlsx
# Lookups para la Tabla plana oficial (cuadros complementarios 2018-2024).
# Se parte de las clasificaciones propias (pan_v02) y del Diccionario oficial.
# Revisar a mano las hojas marcadas con `revisar = TRUE` antes de usar.
# Renato Vargas

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(openxlsx)

rm(list = ls())
source("scripts/00-funciones.R")

ruta_tabla <- "data/cou_flat/P0705547520260930134459Cuadros complementarios a precios corrientes años 2018-24.xlsx"
ruta_v02 <- "data/config/pan_v02_equivalencias.xlsx"
ruta_v03 <- "data/config/pan_v03_equivalencias.xlsx"

# Insumos ---------------------------------------------------------------------

tabla <- leer_tabla_oficial(ruta_tabla) |>
  filter(Anio <= 2024, Cou == "C") |>
  separar_actividad()

cuadrantes_v02 <- read_xlsx(ruta_v02, sheet = "cuadrantes")
columnas_v02 <- read_xlsx(ruta_v02, sheet = "columnas")
filas_v02 <- read_xlsx(ruta_v02, sheet = "filas")

diccionario <- read_xlsx(
  ruta_tabla,
  sheet = "Diccionario",
  col_names = c("Idf", "Descripcion", "x"),
  col_types = "text"
) |>
  select(Idf, Descripcion)

# Hoja 1. cuadrantes ----------------------------------------------------------

cuadrantes <- cuadrantes_v02 |>
  select(codigo_cuadrante, cuadrante, cuadro)

# Hoja 2. transacciones -------------------------------------------------------
# nivel:
#   dato          -> se conserva (dato individual)
#   total         -> suma de otras transacciones; se elimina
#   fuera_alcance -> no es parte del SCN monetario de la base (empleo, índices,
#                    encadenados, remuneraciones, etc.); se elimina

transacciones_base <- tribble(
  ~Idf_Transaccion, ~nivel,  ~codigo_cuadrante, ~atc,    ~cod_trans, ~condicion,
  # Oferta (q01)
  "P00101",         "dato",  "q01",             "ATC01", 1,          "Mercado",
  "P00102",         "dato",  "q01",             "ATC01", 2,          "Uso final propio",
  "P00103",         "dato",  "q01",             "ATC01", 3,          "No de mercado",
  "P0071",          "dato",  "q01",             "ATC02", 20,         NA,
  "P0072",          "dato",  "q01",             "ATC02", 21,         NA,
  "D00211",         "dato",  "q01",             "ATC04", 23,         NA,
  "D00212",         "dato",  "q01",             "ATC04", 24,         NA,
  "D00214",         "dato",  "q01",             "ATC04", 26,         NA,
  "D0031",          "dato",  "q01",             "ATC04", 28,         NA,
  # Utilización (q02)
  "P00201",         "dato",  "q02",             "ATC01", 1,          "Mercado",
  "P00202",         "dato",  "q02",             "ATC01", 2,          "Uso final propio",
  "P00203",         "dato",  "q02",             "ATC01", 3,          "No de mercado",
  "P0061",          "dato",  "q02",             "ATC02", 18,         NA,
  "P0062",          "dato",  "q02",             "ATC02", 19,         NA,
  "P00301",         "dato",  "q02",             "ATC06", 7,          NA,
  "P00302",         "dato",  "q02",             "ATC06", 8,          NA,
  "P00303",         "dato",  "q02",             "ATC06", 10,         NA,
  "P00501",         "dato",  "q02",             "ATC07", 14,         NA,
  "P00502",         "dato",  "q02",             "ATC07", 16,         NA,
  # Valor agregado (q03)
  "B00101",         "dato",  "q03",             "ATC01", 1,          "Mercado",
  "B00102",         "dato",  "q03",             "ATC01", 2,          "Uso final propio",
  "B00103",         "dato",  "q03",             "ATC01", 3,          "No de mercado",
  # Totales (sumas parciales): se eliminan
  "P001",           "total", NA,                NA,      NA,         NA,
  "P002",           "total", NA,                NA,      NA,         NA,
  "D0021",          "total", NA,                NA,      NA,         NA,
  "P006",           "total", NA,                NA,      NA,         NA,
  "P007",           "total", NA,                NA,      NA,         NA,
  # Derivadas por identidad oferta = utilización (no vienen en la Tabla).
  # Ver derivar_ajustes_oferta() en 00-funciones.R
  "AJUSTE_CIF_FOB",     "dato", "q01",          "ATC03", 22,         NA,
  "MARGEN_COMERCIO",    "dato", "q01",          "ATC05", 30,         NA,
  "MARGEN_ELECTRICIDAD", "dato", "q01",         "ATC05", 32,         NA,
  # Sin datos en la Tabla (el COU oficial la trae en cero): se deja la columna
  # para que el cuadro mantenga su estructura completa
  "D00213",         "dato",  "q01",             "ATC04", 25,         NA
)

transacciones_derivadas <- c(
  "AJUSTE_CIF_FOB",
  "MARGEN_COMERCIO",
  "MARGEN_ELECTRICIDAD"
)

# Transacciones que no están en la Tabla pero sí tienen columna en el cuadro
transacciones_sin_tabla <- c(transacciones_derivadas, "D00213")

# Todo lo demás que trae la Tabla queda como fuera de alcance
transacciones <- tabla |>
  distinct(Idf_Transaccion) |>
  bind_rows(tibble(Idf_Transaccion = transacciones_sin_tabla)) |>
  left_join(transacciones_base, by = "Idf_Transaccion") |>
  mutate(nivel = coalesce(nivel, "fuera_alcance")) |>
  left_join(
    diccionario |> rename(Idf_Transaccion = Idf, `Descripción Diccionario` = Descripcion),
    by = "Idf_Transaccion"
  ) |>
  arrange(factor(nivel, c("dato", "total", "fuera_alcance")), codigo_cuadrante, cod_trans)

# Nombres de transacción de v02 (mismos códigos de transacción por cuadrante)
nombres_trans <- columnas_v02 |>
  mutate(codigo_cuadrante = str_extract(Columnas, "q0\\d")) |>
  filter(!is.na(`Código Transacciones`)) |>
  distinct(
    codigo_cuadrante,
    `Código área transaccional columnas`,
    `Área transaccional columnas`,
    `Código Transacciones`,
    Transacciones,
    `Código transacciones agregadas`,
    `Transacciones agregadas`
  )

transacciones <- transacciones |>
  left_join(
    nombres_trans,
    by = c(
      "codigo_cuadrante",
      "atc" = "Código área transaccional columnas",
      "cod_trans" = "Código Transacciones"
    )
  ) |>
  left_join(cuadrantes, by = "codigo_cuadrante") |>
  rename(
    `Código área transaccional columnas` = atc,
    `Código Transacciones` = cod_trans,
    `Condición de Mercado` = condicion,
    Cuadrante = cuadrante,
    Cuadro = cuadro
  ) |>
  mutate(
    # La Tabla trae ISFLSH y Gobierno sin separar individual / colectivo
    Transacciones = case_when(
      Idf_Transaccion == "P00302" ~ "Gasto de consumo final ISFLSH (individual y colectivo)",
      Idf_Transaccion == "P00303" ~ "Gasto de consumo final del gobierno (individual y colectivo)",
      TRUE ~ Transacciones
    ),
    nota = case_when(
      Idf_Transaccion %in% c("P00302", "P00303") ~
        "La fuente no separa consumo individual y colectivo",
      Idf_Transaccion == "P0071" ~ "Incluye el ajuste CIF/FOB (Idf_Producto = CIF_FOB)",
      Idf_Transaccion %in% transacciones_derivadas ~
        "Derivada por identidad oferta = utilización; no viene en la Tabla",
      Idf_Transaccion == "D00213" ~ "Sin datos en la Tabla; cero en el COU oficial",
      nivel == "total" ~ "Suma parcial: se reconstruye en verificar_totales()",
      nivel == "fuera_alcance" ~ "No forma parte del SCN monetario de la base",
      TRUE ~ NA_character_
    )
  ) |>
  select(
    Idf_Transaccion, nivel, codigo_cuadrante, Cuadro, Cuadrante,
    `Código área transaccional columnas`, `Área transaccional columnas`,
    `Código Transacciones`, Transacciones,
    `Código transacciones agregadas`, `Transacciones agregadas`,
    `Condición de Mercado`, `Descripción Diccionario`, nota
  )

# Hoja 3. actividades ---------------------------------------------------------
# Llave: código base de actividad (sin sufijo). La Condición de Mercado sale de
# la transacción, no del sufijo, para cubrir 49.1 y 50.1-50.3 (sin sufijo).

actividades_v02 <- columnas_v02 |>
  filter(!is.na(`Código Clasificación Actividades`)) |>
  distinct(
    Codigo_AE = `Código Clasificación Actividades`,
    `Descripción Actividades`,
    `CIIU Secciones`,
    `CIIU Secciones descripción`,
    `CIIU Corto`,
    `Código Actividades Agregadas`,
    `Actividades Agregadas`,
    `Código Bioeconomía Actividades`,
    `Bioeconomía Actividades`
  ) |>
  mutate(revisar = FALSE)

# Actividades de la Tabla sin clasificar en v02 (36.2 y 36.3 desde la apertura
# de construcción). Se heredan de 36.1 y se marcan para revisión.
nuevas <- tabla |>
  filter(!is.na(Codigo_AE), !Codigo_AE %in% actividades_v02$Codigo_AE) |>
  distinct(Codigo_AE, Idf_Categoria) |>
  left_join(
    diccionario |>
      mutate(Codigo_AE = str_extract(Idf, "^\\d+\\.\\d+")) |>
      filter(!is.na(Codigo_AE)) |>
      slice(1, .by = Codigo_AE) |>
      select(Codigo_AE, `Descripción Actividades` = Descripcion),
    by = "Codigo_AE"
  ) |>
  mutate(`Descripción Actividades` = str_to_sentence(`Descripción Actividades`))

heredar <- actividades_v02 |>
  filter(Codigo_AE == "36.1") |>
  select(-Codigo_AE, -`Descripción Actividades`, -revisar)

actividades <- bind_rows(
  actividades_v02,
  nuevas |>
    select(-Idf_Categoria) |>
    cross_join(heredar) |>
    mutate(revisar = TRUE)
) |>
  arrange(match(Codigo_AE, str_sort(unique(Codigo_AE), numeric = TRUE)))

# Hoja 4. filas (productos) ---------------------------------------------------
# Se reutilizan las filas de v02 con producto o área transaccional asignada.
# Llave Idf_Producto: código de 4 dígitos, o el código especial de la Tabla para
# ajuste CIF/FOB y compras directas, o "B.1" para valor agregado.

llave_especial <- c(
  ATF03 = "CIF_FOB",
  ATF04a = "6701",
  ATF04b = "6702",
  ATF05a = "6703",
  ATF05b = "6704",
  ATF06 = "B.1"
)

filas <- filas_v02 |>
  mutate(codigo_cuadrante = str_extract(Filas, "q0\\d")) |>
  filter(!is.na(`Áreas Transaccionales Filas No.`)) |>
  mutate(
    Idf_Producto = coalesce(
      `Código Nomenclatura Local de Productos`,
      llave_especial[`Áreas Transaccionales Filas No.`]
    )
  ) |>
  select(-Filas) |>
  mutate(
    Filas = sprintf(
      "pan_v03_%s_f%04d",
      codigo_cuadrante,
      row_number()
    ),
    .by = codigo_cuadrante
  ) |>
  select(codigo_cuadrante, Idf_Producto, Filas, everything())

# Hoja 5. columnas (transacción x actividad) ----------------------------------
# Una columna por combinación presente en la Tabla, ordenada por transacción y
# luego por código de actividad.

columnas <- tabla |>
  select(Idf_Transaccion, Codigo_AE) |>
  bind_rows(tibble(
    Idf_Transaccion = transacciones_sin_tabla,
    Codigo_AE = NA_character_
  )) |>
  inner_join(
    transacciones |> filter(nivel == "dato"),
    by = "Idf_Transaccion"
  ) |>
  distinct(
    codigo_cuadrante, Idf_Transaccion, Codigo_AE,
    `Código Transacciones`
  ) |>
  arrange(
    codigo_cuadrante,
    `Código Transacciones`,
    match(Codigo_AE, str_sort(unique(Codigo_AE), numeric = TRUE))
  ) |>
  mutate(
    Columnas = sprintf("pan_v03_%s_c%04d", codigo_cuadrante, row_number()),
    .by = codigo_cuadrante
  ) |>
  left_join(
    transacciones |>
      filter(nivel == "dato") |>
      select(
        Idf_Transaccion,
        `Código área transaccional columnas`,
        `Área transaccional columnas`,
        Transacciones,
        `Código transacciones agregadas`,
        `Transacciones agregadas`,
        `Condición de Mercado`
      ),
    by = "Idf_Transaccion"
  ) |>
  left_join(actividades |> select(-revisar), by = "Codigo_AE") |>
  mutate(`Código Clasificación Actividades` = Codigo_AE)

# Exportar --------------------------------------------------------------------

wb <- createWorkbook()
hojas <- list(
  cuadrantes = cuadrantes,
  transacciones = transacciones,
  actividades = actividades,
  filas = filas,
  columnas = columnas
)
for (h in names(hojas)) {
  addWorksheet(wb, h)
  writeData(wb, h, hojas[[h]])
}
saveWorkbook(wb, ruta_v03, overwrite = TRUE)
