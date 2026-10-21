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


# ==============================================================================
# Funciones para procesar la TABLA PLANA oficial (cuadros complementarios)
# Se usan en scripts/09-procesamiento-tabla-oficial.R
# ==============================================================================

# Paso 1. Leer la hoja "Tabla" -------------------------------------------------

# Lee la hoja "Tabla" tal cual viene (todo como texto para no perder
# etiquetas como "2024 (P)") y la deja con tipos correctos:
#   Anio    : entero (2018, 2019, ...)
#   Estatus : "Definitivo", "P" (provisional) o "E" (estimado)
#   Valor   : numérico
leer_tabla_oficial <- function(ruta, hoja = "Tabla") {
  readxl::read_excel(ruta, sheet = hoja, col_types = "text") |>
    dplyr::select(
      `Año`,
      Idf_Transaccion,
      Idf_Actividad,
      Idf_Categoria,
      Idf_Producto,
      Valor,
      Cou
    ) |>
    dplyr::filter(!is.na(Idf_Transaccion)) |>
    dplyr::mutate(
      Anio = as.integer(stringr::str_extract(`Año`, "^\\d{4}")),
      Estatus = dplyr::case_when(
        stringr::str_detect(`Año`, "\\(P\\)") ~ "P",
        stringr::str_detect(`Año`, "\\(E\\)") ~ "E",
        TRUE ~ "Definitivo"
      ),
      Valor = as.numeric(Valor),
      .before = 1
    ) |>
    dplyr::select(-`Año`)
}

# Paso 2. Separar código de actividad y sufijo --------------------------------

# "36.1 UFP" -> Codigo_AE = "36.1", Sufijo = "UFP"
# "49.1"     -> Codigo_AE = "49.1", Sufijo = NA
# "00"       -> Codigo_AE = NA (no es una actividad: demanda final, etc.)
separar_actividad <- function(tabla) {
  tabla |>
    dplyr::mutate(
      Codigo_AE = stringr::str_extract(Idf_Actividad, "^\\d+\\.\\d+"),
      Sufijo = stringr::str_extract(Idf_Actividad, "(?<=\\s)[A-Z]+$")
    )
}

# Paso 3. Dejar solo datos individuales ---------------------------------------

# La Tabla mezcla datos puros con sumas parciales y totales. Se eliminan:
#   a) Transacciones marcadas como "total" o "fuera_alcance" en el lookup
#      (p. ej. P001 = suma de P00101 + P00102 + P00103).
#   b) Filas con Idf_Producto == "00": son el total de cada actividad (si se
#      dejan, los valores quedan duplicados).
#   c) Series que no son corrientes (Cou != "C"): encadenados, índices, etc.
filtrar_datos_individuales <- function(tabla, equiv_transacciones) {
  tabla |>
    dplyr::filter(Cou == "C", Idf_Producto != "00") |>
    dplyr::inner_join(
      equiv_transacciones |>
        dplyr::filter(nivel == "dato") |>
        dplyr::select(Idf_Transaccion, codigo_cuadrante, Cuadro, Cuadrante),
      by = "Idf_Transaccion"
    )
}

# Paso 3b. Derivar márgenes y ajuste CIF/FOB ----------------------------------

# La Tabla plana NO trae las columnas de márgenes de distribución ni la de
# ajuste CIF/FOB del cuadro de oferta. Se recuperan por identidad contable:
# para cada producto, oferta total = utilización total, así que
#   residuo = utilización total - (producción + importaciones + impuestos)
# El residuo de las filas de transporte y seguros de importación y de la fila
# CIF_FOB es el ajuste CIF/FOB (columna ATC03); el resto son márgenes. Los
# márgenes de electricidad (4501 / 4502) se separan de los de comercio.
# Validado: reproduce exactamente las columnas del COU oficial 2022-2024 y las
# celdas de pan_scn.RDS 2018-2021 (ver scripts/10-validar-contra-cou-oficial.R).
derivar_ajustes_oferta <- function(
  datos,
  equiv_transacciones,
  productos_cif_fob = c("4902", "4905", "4907", "5303", "CIF_FOB"),
  productos_margen_electricidad = c("4501", "4502"),
  tolerancia = 1e-9
) {
  residuo <- datos |>
    dplyr::filter(codigo_cuadrante %in% c("q01", "q02")) |>
    dplyr::summarize(
      total = sum(Valor),
      .by = c(Anio, Estatus, Idf_Producto, codigo_cuadrante)
    ) |>
    tidyr::pivot_wider(
      names_from = codigo_cuadrante,
      values_from = total,
      values_fill = 0
    ) |>
    dplyr::mutate(Valor = q02 - q01) |>
    dplyr::filter(abs(Valor) > tolerancia)

  residuo |>
    dplyr::mutate(
      Idf_Transaccion = dplyr::case_when(
        Idf_Producto %in% productos_cif_fob ~ "AJUSTE_CIF_FOB",
        Idf_Producto %in% productos_margen_electricidad ~ "MARGEN_ELECTRICIDAD",
        TRUE ~ "MARGEN_COMERCIO"
      ),
      Idf_Actividad = "00",
      Idf_Categoria = "00",
      Cou = "C",
      Codigo_AE = NA_character_,
      Sufijo = NA_character_
    ) |>
    dplyr::select(-q01, -q02) |>
    dplyr::inner_join(
      equiv_transacciones |>
        dplyr::select(Idf_Transaccion, codigo_cuadrante, Cuadro, Cuadrante),
      by = "Idf_Transaccion"
    )
}

# Paso 4. Unir clasificaciones ------------------------------------------------

# Une el lookup de columnas (transacción x actividad) y de filas (producto).
# Las llaves son los códigos de la Tabla, nunca posiciones del Excel.
agregar_clasificaciones <- function(datos, equiv_columnas, equiv_filas) {
  datos |>
    dplyr::left_join(
      equiv_columnas,
      by = c("codigo_cuadrante", "Idf_Transaccion", "Codigo_AE"),
      na_matches = "na"
    ) |>
    dplyr::left_join(
      equiv_filas,
      by = c("codigo_cuadrante", "Idf_Producto")
    )
}

# Paso 4b. Completar el cuadro con ceros --------------------------------------

# La Tabla solo trae celdas distintas de cero. Los cuadros de oferta y
# utilización son rectangulares, así que se arma la rejilla completa
# (todas las filas x todas las columnas de cada cuadrante, por año) y se
# rellena con los valores; lo que no está en la Tabla queda en 0.
# Si algún valor no cae en la rejilla se detiene con error (no se pierde nada).
completar_cuadrantes <- function(
  datos,
  equiv_filas,
  equiv_columnas,
  equiv_cuadrantes
) {
  valores <- datos |>
    dplyr::summarize(
      Valor = sum(Valor),
      .by = c(Anio, Estatus, Filas, Columnas)
    )

  anios <- dplyr::distinct(datos, Anio, Estatus)

  rejilla <- purrr::map(equiv_cuadrantes$codigo_cuadrante, \(q) {
    filas_q <- equiv_filas |>
      dplyr::filter(codigo_cuadrante == q) |>
      dplyr::select(-codigo_cuadrante, -Idf_Producto)
    columnas_q <- equiv_columnas |>
      dplyr::filter(codigo_cuadrante == q) |>
      dplyr::select(-codigo_cuadrante, -Idf_Transaccion, -Codigo_AE)

    anios |>
      dplyr::cross_join(filas_q) |>
      dplyr::cross_join(columnas_q) |>
      dplyr::mutate(codigo_cuadrante = q)
  }) |>
    dplyr::bind_rows() |>
    dplyr::left_join(
      equiv_cuadrantes |>
        dplyr::rename(Cuadrante = cuadrante, Cuadro = cuadro),
      by = "codigo_cuadrante"
    ) |>
    dplyr::left_join(valores, by = c("Anio", "Estatus", "Filas", "Columnas")) |>
    dplyr::mutate(Valor = tidyr::replace_na(Valor, 0))

  perdido <- sum(valores$Valor) - sum(rejilla$Valor)
  if (abs(perdido) > 1e-6) {
    stop("Hay valores que no caen en la rejilla de filas x columnas: ", perdido)
  }

  rejilla
}

# Paso 5. Control: llaves sin clasificar --------------------------------------

# Devuelve las combinaciones de la Tabla que no encontraron fila o columna en
# los lookups. Debe quedar vacío; si no, hay que completar las equivalencias.
reportar_sin_mapear <- function(datos) {
  datos |>
    dplyr::filter(is.na(Filas) | is.na(Columnas)) |>
    dplyr::count(
      Idf_Transaccion,
      Idf_Actividad,
      Idf_Producto,
      sin_fila = is.na(Filas),
      sin_columna = is.na(Columnas),
      name = "n_registros"
    )
}

# Paso 6. Control: condición de mercado coherente con el sufijo ---------------

# El sufijo del código de actividad (M / NM / UFP) debe coincidir con la
# Condición de Mercado derivada de la transacción. Devuelve las filas que
# contradicen (debe quedar vacío).
verificar_condicion_mercado <- function(datos) {
  esperado <- c(
    M = "Mercado",
    UFP = "Uso final propio",
    NM = "No de mercado"
  )
  datos |>
    dplyr::filter(!is.na(Sufijo)) |>
    dplyr::filter(esperado[Sufijo] != `Condición de Mercado`) |>
    dplyr::distinct(Idf_Transaccion, Idf_Actividad, `Condición de Mercado`)
}

# Paso 7. Control: reconstruir los totales eliminados -------------------------

# Compara cada total oficial (P001, P002, D0021, P006, P007) con la suma de sus
# componentes individuales, por año y producto. Diferencias distintas de cero
# indican que se eliminó o se dejó algo que no se debía.
verificar_totales <- function(tabla, tolerancia = 1e-6) {
  jerarquia <- tibble::tribble(
    ~total,  ~componente,
    "P001",  "P00101",
    "P001",  "P00102",
    "P001",  "P00103",
    "P002",  "P00201",
    "P002",  "P00202",
    "P002",  "P00203",
    "D0021", "D00211",
    "D0021", "D00212",
    "D0021", "D00214",
    "P006",  "P0061",
    "P006",  "P0062",
    "P007",  "P0071",
    "P007",  "P0072"
  )

  base <- tabla |>
    dplyr::filter(Cou == "C", Idf_Producto != "00")

  oficial <- base |>
    dplyr::filter(Idf_Transaccion %in% jerarquia$total) |>
    dplyr::summarize(
      total_oficial = sum(Valor),
      .by = c(Anio, Idf_Transaccion, Idf_Producto)
    )

  reconstruido <- base |>
    dplyr::inner_join(
      jerarquia,
      by = c("Idf_Transaccion" = "componente")
    ) |>
    dplyr::summarize(
      suma_componentes = sum(Valor),
      .by = c(Anio, total, Idf_Producto)
    ) |>
    dplyr::rename(Idf_Transaccion = total)

  dplyr::full_join(
    oficial,
    reconstruido,
    by = c("Anio", "Idf_Transaccion", "Idf_Producto")
  ) |>
    dplyr::mutate(
      dplyr::across(c(total_oficial, suma_componentes), ~ tidyr::replace_na(.x, 0)),
      diferencia = total_oficial - suma_componentes
    ) |>
    dplyr::filter(abs(diferencia) > tolerancia)
}

# Paso 8. Esquema final -------------------------------------------------------

# Ordena y renombra al mismo esquema de salidas/pan_scn.RDS (33 columnas),
# más dos columnas nuevas: `Condición de Mercado` y `Estatus`.
armar_esquema_pan_scn <- function(
  datos,
  unidad = "millones de B/.",
  precios = "Corrientes"
) {
  datos |>
    dplyr::mutate(
      `Año` = as.numeric(Anio),
      Unidades = unidad,
      Precios = precios
    ) |>
    dplyr::select(
      Filas, Columnas, Valor, `Año`, Cuadro, Cuadrante, Unidades, Precios,
      `Código área transaccional columnas`,
      `Área transaccional columnas`,
      `Código Transacciones`,
      Transacciones,
      `Código transacciones agregadas`,
      `Transacciones agregadas`,
      `Código Clasificación Actividades`,
      `Descripción Actividades`,
      `CIIU Secciones`,
      `CIIU Secciones descripción`,
      `CIIU Corto`,
      `Código Actividades Agregadas`,
      `Actividades Agregadas`,
      `Código Bioeconomía Actividades`,
      `Bioeconomía Actividades`,
      `Áreas Transaccionales Filas No.`,
      `Áreas Transaccionales Filas Descripción`,
      `Código Nomenclatura Local de Productos`,
      `Nomenclatura Local de Productos`,
      `Código CPC`,
      `Elemento CPC`,
      `Código Productos Agregados`,
      `Productos Agregados`,
      `Código Bioeconomía Productos`,
      `Clasificación Bioeconomía Productos`,
      `Condición de Mercado`,
      Estatus
    ) |>
    dplyr::arrange(`Año`, Cuadro, Filas, Columnas)
}


# ==============================================================================
# Validación contra los COU oficiales (data/cou_oficial)
# ==============================================================================

# Lee un COU oficial (hojas Oferta y Utilización) en formato largo:
# una fila por producto x columna. Las columnas se identifican por sus
# encabezados (filas 8 a 11), no por posición, así que sirve para archivos con
# distinto número de columnas (2018-2021 vs 2022-2024). Los subtotales y
# totales de columna se descartan.
leer_cou_oficial <- function(ruta, anio) {
  clave_columna <- function(i, r8, r9, r10, r11) {
    if (i <= 2) {
      return(NA_character_)
    }
    codigo <- r10[i]
    t <- stringr::str_squish(stringr::str_to_upper(
      paste(r8[i], r9[i], r10[i], r11[i])
    ))
    if (!is.na(codigo) && stringr::str_detect(codigo, "^\\d+\\.\\d+( [A-Z]+)?$")) {
      # Algunos códigos (39.2) llegan como número con ruido decimal
      if (stringr::str_detect(codigo, "^\\d+\\.\\d{4,}")) {
        codigo <- sprintf("%.1f", as.numeric(codigo))
      }
      return(paste0("ACT|", codigo))
    }
    dplyr::case_when(
      stringr::str_detect(t, "P\\.71") ~ "P0071",
      stringr::str_detect(t, "P\\.72") ~ "P0072",
      stringr::str_detect(t, "P\\.61") ~ "P0061",
      stringr::str_detect(t, "P\\.62") ~ "P0062",
      stringr::str_detect(t, "D\\.211") ~ "D00211",
      stringr::str_detect(t, "D\\.212") ~ "D00212",
      stringr::str_detect(t, "D\\.213") ~ "D00213",
      stringr::str_detect(t, "D\\.214") ~ "D00214",
      stringr::str_detect(t, "D\\.31") ~ "D0031",
      stringr::str_detect(t, "AJUSTE CIF/FOB") ~ "AJUSTE_CIF_FOB",
      stringr::str_detect(t, "MÁRGENES DE COMERCIO") ~ "MARGEN_COMERCIO",
      stringr::str_detect(t, "MÁRGENES DE DISTRIBUCIÓN DE ELECT") ~ "MARGEN_ELECTRICIDAD",
      stringr::str_detect(t, "P31 HOGARES") ~ "P00301",
      stringr::str_detect(t, "SUBTOTAL ISFLSH") ~ "P00302",
      stringr::str_detect(t, "SUBTOTAL GOBIERNO") ~ "P00303",
      stringr::str_detect(t, "P\\.51 FORMACION") ~ "P00501",
      stringr::str_detect(t, "P\\.52 VARIACION") ~ "P00502",
      TRUE ~ NA_character_
    )
  }

  leer_hoja <- function(hoja) {
    x <- readxl::read_excel(
      ruta, sheet = hoja, col_names = FALSE,
      col_types = "text", .name_repair = "minimal"
    )
    r8 <- unlist(x[8, ]); r9 <- unlist(x[9, ])
    r10 <- unlist(x[10, ]); r11 <- unlist(x[11, ])
    claves <- vapply(
      seq_len(ncol(x)), clave_columna, character(1),
      r8 = r8, r9 = r9, r10 = r10, r11 = r11
    )

    datos <- x[12:208, ]
    producto <- datos[[1]]
    producto <- dplyr::if_else(
      stringr::str_detect(producto, "^Ajustes"), "CIF_FOB", producto
    )
    filas <- which(
      !is.na(producto) &
        (stringr::str_detect(producto, "^\\d{4}$") | producto == "CIF_FOB")
    )
    columnas <- which(!is.na(claves))

    m <- suppressWarnings(
      matrix(as.numeric(as.matrix(datos[filas, columnas])), length(filas))
    )
    m[is.na(m)] <- 0

    tibble::tibble(
      Producto = rep(producto[filas], times = length(columnas)),
      Clave = rep(claves[columnas], each = length(filas)),
      Valor = as.vector(m),
      Cuadro = hoja,
      Anio = anio
    )
  }

  dplyr::bind_rows(leer_hoja("Oferta"), leer_hoja("Utilización"))
}

# Condición de mercado de una actividad del COU oficial ("36.1 UFP" -> "Uso
# final propio"). Sin sufijo: 49.1 es uso final propio y 50.x no de mercado.
condicion_mercado_oficial <- function(codigo) {
  sufijo <- stringr::str_extract(codigo, "(?<= )[A-Z]+$")
  base <- stringr::str_extract(codigo, "^\\d+\\.\\d+")
  dplyr::case_when(
    sufijo == "M" ~ "Mercado",
    sufijo == "UFP" ~ "Uso final propio",
    sufijo == "NM" ~ "No de mercado",
    base == "49.1" ~ "Uso final propio",
    stringr::str_starts(base, "50") ~ "No de mercado",
    TRUE ~ "Mercado"
  )
}

# Pone el COU oficial y la base procesada (pan_scn_oficial) en la misma llave:
#   Anio x Cuadro x Producto x Clave (actividad|condición o transacción)
# Las actividades 36.2 y 36.3 se suman a 36.1 cuando `colapsar_construccion`
# es TRUE (los COU oficiales 2018-2021 traen una sola columna de construcción).
armonizar_llaves <- function(oficial, base, colapsar_construccion = TRUE) {
  colapsa <- function(b) {
    if (colapsar_construccion) dplyr::if_else(b %in% c("36.2", "36.3"), "36.1", b) else b
  }
  clave_trans <- c(
    q01_20 = "P0071", q01_21 = "P0072", q01_22 = "AJUSTE_CIF_FOB",
    q01_23 = "D00211", q01_24 = "D00212", q01_25 = "D00213",
    q01_26 = "D00214", q01_28 = "D0031",
    q01_30 = "MARGEN_COMERCIO", q01_32 = "MARGEN_ELECTRICIDAD",
    q02_7 = "P00301", q02_8 = "P00302", q02_10 = "P00303",
    q02_14 = "P00501", q02_16 = "P00502", q02_18 = "P0061", q02_19 = "P0062"
  )
  especial <- c(
    ATF03 = "CIF_FOB", ATF04a = "6701", ATF04b = "6702",
    ATF05a = "6703", ATF05b = "6704"
  )

  of <- oficial |>
    dplyr::mutate(
      act = stringr::str_remove(Clave, "^ACT\\|"),
      Clave = dplyr::if_else(
        stringr::str_starts(Clave, "ACT\\|"),
        paste0(
          colapsa(stringr::str_extract(act, "^\\d+\\.\\d+")), "|",
          condicion_mercado_oficial(act)
        ),
        Clave
      )
    ) |>
    dplyr::summarize(oficial = sum(Valor), .by = c(Anio, Cuadro, Producto, Clave))

  nu <- base |>
    dplyr::filter(Cuadro != "03 Valor Agregado") |>
    dplyr::mutate(
      q = dplyr::if_else(Cuadro == "01 Oferta", "q01", "q02"),
      Anio = `Año`,
      Producto = dplyr::coalesce(
        `Código Nomenclatura Local de Productos`,
        especial[`Áreas Transaccionales Filas No.`]
      ),
      Clave = dplyr::if_else(
        `Código área transaccional columnas` == "ATC01",
        paste0(
          colapsa(`Código Clasificación Actividades`), "|",
          `Condición de Mercado`
        ),
        clave_trans[paste0(q, "_", `Código Transacciones`)]
      ),
      Cuadro = dplyr::if_else(Cuadro == "01 Oferta", "Oferta", "Utilización")
    ) |>
    dplyr::summarize(nueva = sum(Valor), .by = c(Anio, Cuadro, Producto, Clave))

  dplyr::full_join(of, nu, by = c("Anio", "Cuadro", "Producto", "Clave")) |>
    dplyr::mutate(
      dplyr::across(c(oficial, nueva), ~ tidyr::replace_na(.x, 0)),
      diferencia = nueva - oficial
    )
}

# Concepto macroeconómico de cada celda comparada
concepto_macro <- function(clave, cuadro) {
  dplyr::case_when(
    stringr::str_detect(clave, "\\|") & cuadro == "Oferta" ~ "Producción",
    stringr::str_detect(clave, "\\|") ~ "Consumo intermedio",
    stringr::str_starts(clave, "P007") ~ "Importaciones",
    clave == "AJUSTE_CIF_FOB" ~ "Ajuste CIF/FOB",
    stringr::str_starts(clave, "MARGEN") ~ "Márgenes",
    stringr::str_starts(clave, "D0") ~ "Impuestos netos",
    stringr::str_starts(clave, "P003") ~ "Consumo final",
    stringr::str_starts(clave, "P005") ~ "Formación de capital",
    stringr::str_starts(clave, "P006") ~ "Exportaciones",
    TRUE ~ "Otro"
  )
}
