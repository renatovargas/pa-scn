# Funciones para procesar Cuadros de Oferta y Utilización
# Renato Vargas

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)
library(openxlsx)

# Herramientas

procesar_indices <- function(x) {
  if (is.na(x) || x == "") {
    return(integer(0))
  }
  as.integer(str_split(x, ",")[[1]] %>% str_trim())
}

# Cargar config

cargar_config <- function(iso3, ruta_config) {
  config <- readxl::read_xlsx(
    file.path(ruta_config, paste0(tolower(iso3), "_config.xlsx"))
  )

  versiones <- unique(config$v_equivalencias)

  equivalencias <- vector("list", length(versiones))
  names(equivalencias) <- versiones

  for (v in versiones) {
    archivo_equivalencias <- file.path(
      ruta_config,
      paste0(tolower(iso3), "_", v, "_equivalencias.xlsx")
    )

    equivalencias[[v]] <- readxl::read_xlsx(
      archivo_equivalencias,
      sheet = "cuadrantes"
    ) |>
      dplyr::select(-cuadrante)
  }

  lista_config <- vector("list", nrow(config))

  for (i in seq_len(nrow(config))) {
    fila <- config[i, ]
    v <- fila$v_equivalencias[[1]]

    lista_config[[i]] <- dplyr::left_join(
      fila,
      equivalencias[[v]],
      by = "codigo_cuadrante"
    )
  }

  dplyr::bind_rows(lista_config)
}


# Procesar cuadrante

procesar_cuadrante <- function(
  iso3,
  anio,
  v_equivalencias,
  codigo_cuadrante,
  cuadrante,
  archivo,
  hoja,
  cuadro,
  rango,
  excluir_filas,
  excluir_columnas,
  unidad,
  precios
) {
  df <- readxl::read_excel(
    archivo,
    range = paste0("'", hoja, "'!", rango),
    col_names = FALSE,
    col_types = "numeric"
  )

  n_filas <- nrow(df)
  n_columnas <- ncol(df)

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

  df <- df |>
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ tidyr::replace_na(.x, 0)
      )
    ) |>
    stats::setNames(cod_columnas) |>
    dplyr::mutate(
      Filas = cod_filas,
      .before = 1
    )

  if (length(excluir_filas) > 0) {
    df <- df[-excluir_filas, , drop = FALSE]
  }

  if (length(excluir_columnas) > 0) {
    # Puesto que agregamos una columna de nombres al inicio
    # debemos correr las columnas a excluir por una posición
    # lo que se logra con (exlcuir_columnas + 1) abajo.
    # Otra forma de hacerlo sería quitar el .before = 1 en
    # la línaea 77 en el último mutate() de arriba para que
    # quede al final y no modifique las posiciones, pero esto
    # funciona bien.
    df <- df[, -(excluir_columnas + 1), drop = FALSE]
  }

  df <- df |>
    tidyr::pivot_longer(
      cols = -Filas,
      names_to = "Columnas",
      values_to = "Valor"
    ) |>
    dplyr::mutate(
      `Año` = anio,
      Cuadro = cuadro,
      Cuadrante = cuadrante,
      Unidades = unidad,
      Precios = precios
    )

  return(df)
}
