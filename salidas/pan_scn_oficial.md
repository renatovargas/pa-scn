# `pan_scn_oficial.RDS`: descripción y construcción

Base de datos consolidada de los Cuadros de Oferta y Utilización (COU) de Panamá, 2018-2024, con la clasificación bioeconómica de productos y actividades. Es la **única fuente de verdad** del repositorio: el documento `documentos/cb-panama.qmd`, el Excel `COU-BIO-agregado-2018-2024.xlsx` y los scripts 06-08 leen este archivo.

Archivos equivalentes, con el mismo contenido: `salidas/pan_scn_oficial.xlsx` (hoja `PAN_SCN_BD`, vacíos como "-") y la tabla `pan_scn_oficial` en `salidas/pan_scn.duckdb`.

## Forma de los datos

- **Formato largo (tidy):** una fila por celda de un cuadro, es decir, por combinación de año × fila (producto o concepto) × columna (actividad o transacción). 265.426 filas × 35 columnas (tibble).
- **Años:** 2018-2024, 37.918 filas por año. `Estatus` = "Definitivo" (2018-2023) o "P" (2024, provisional).
- **Unidades:** millones de balboas (B/.), precios corrientes (`Unidades`, `Precios`).
- **Rejilla completa:** los cuadros son rectangulares; las celdas que la fuente no trae están en 0 (no ausentes).
- **No hay totales ni subtotales:** solo datos individuales. Para totales hay que sumar.

### Cuadros (`Cuadro` / `Cuadrante`)

| Cuadro | Filas (n) | Contenido |
|---|---|---|
| `01 Oferta` | 135.100 | Oferta por producto: producción por actividad, importaciones, ajuste CIF/FOB, impuestos, subvenciones, márgenes |
| `02 Utilización` | 129.696 | Utilización por producto: consumo intermedio por actividad, exportaciones, consumo final, formación de capital |
| `03 Valor Agregado` | 630 | Valor agregado bruto por actividad (una sola fila de producto: ATF06) |

Cada cuadro tiene un único cuadrante (códigos internos q01, q02, q03).

## Columnas (35)

**Llaves y valor**
- `Filas`, `Columnas`: códigos sintéticos `pan_v03_q0X_f####` y `pan_v03_q0X_c####`, generados por orden dentro de cada cuadrante (no son posiciones de Excel). Se resuelven con las hojas `filas` y `columnas` de `data/config/pan_v03_equivalencias.xlsx`.
- `Valor` (numérico), `Año` (numérico), `Cuadro`, `Cuadrante`, `Unidades`, `Precios`.

**Clasificación de columnas** (qué es la columna)
- `Código área transaccional columnas` / `Área transaccional columnas`: ATC01 producción / consumo intermedio; ATC02 exportaciones / importaciones; ATC03 ajuste CIF/FOB; ATC04 impuestos menos subvenciones; ATC05 márgenes de distribución; ATC06 consumo final; ATC07 formación bruta de capital.
- `Código Transacciones` / `Transacciones`, `Código transacciones agregadas` / `Transacciones agregadas`.
- Actividad (solo en ATC01): `Código Clasificación Actividades` (p. ej. "01.1", "36.2"), `Descripción Actividades`, `CIIU Secciones` (A-T), `CIIU Secciones descripción`, `CIIU Corto`, `Código Actividades Agregadas` / `Actividades Agregadas` (Sector primario, Manufacturas, Servicios), `Código Bioeconomía Actividades` / `Bioeconomía Actividades`.
- `Condición de Mercado`: Mercado, Uso final propio, No de mercado. Es NA fuera de ATC01.

**Clasificación de filas** (qué es la fila)
- `Áreas Transaccionales Filas No.` / `... Descripción`: ATF01 producción (cuadro de oferta); ATF02 consumo intermedio (utilización); ATF03 ajuste CIF/FOB; ATF04a/b y ATF05a/b compras directas (exterior por residentes, territorio por no residentes; embajadas y viajes); ATF06 valor agregado.
- Producto (solo ATF01/ATF02): `Código Nomenclatura Local de Productos` (4 dígitos), `Nomenclatura Local de Productos`, `Código CPC`, `Elemento CPC`, `Código Productos Agregados` / `Productos Agregados`.
- `Código Bioeconomía Productos` / `Clasificación Bioeconomía Productos`: Bioeconomía, Bioeconomía extendida, No bioeconomía.

**Control**
- `Estatus`: Definitivo o P.

### Valores NA esperados

- Sin actividad (NA en 9 columnas de actividad, `Condición de Mercado`): 22.967 filas de columnas que no son producción/consumo intermedio (importaciones, impuestos, consumo final, etc.).
- Sin producto (NA en 8 columnas de producto): 7.490 filas de ajuste CIF/FOB, compras directas y valor agregado, que no son productos y **no tienen clasificación bioeconómica**.

## Cómo se construyó

Fuente: `data/cou_flat/P0705547520260930134459Cuadros complementarios a precios corrientes años 2018-24.xlsx`, hoja `Tabla` (69.274 filas: `Año`, `Idf_Transaccion`, `Idf_Actividad`, `Idf_Categoria`, `Idf_Producto`, `Valor`, `Cou`) y hoja `Diccionario`. La Tabla mezcla datos individuales con sumas parciales y no identifica cuadros ni áreas transaccionales; las equivalencias propias lo resuelven.

Pipeline (ejecutar desde la raíz del repositorio):

1. `scripts/09a-crear-equivalencias-v03.R` construye `data/config/pan_v03_equivalencias.xlsx` (hojas `cuadrantes`, `transacciones`, `actividades`, `filas`, `columnas`) a partir de las clasificaciones propias `pan_v02_equivalencias.xlsx` y del Diccionario. Las hojas `actividades` y `transacciones` tienen la columna `revisar`/`nivel`.
2. `scripts/09-procesamiento-tabla-oficial.R` aplica los pasos, con funciones de `scripts/00-funciones.R`:
   1. `leer_tabla_oficial()`: lee todo como texto; `Año` ("2024 (P)") se separa en año numérico y `Estatus`; se excluye 2025 (E), que solo tiene 2 filas.
   2. `verificar_totales()`: comprueba que cada total oficial (P001, P002, D0021, P006, P007) iguala la suma de sus componentes (diferencia 0).
   3. `separar_actividad()`: "36.1 UFP" → código "36.1" + sufijo "UFP".
   4. `filtrar_datos_individuales()`: conserva solo `Cou == "C"`, quita los totales, las filas con `Idf_Producto == "00"` (total de la actividad; duplicaría valores) y las transacciones fuera del SCN monetario (empleo, remuneraciones, IPC, FBK, encadenados, etc.), según la columna `nivel` del lookup `transacciones`.
   5. `derivar_ajustes_oferta()`: la Tabla no trae márgenes de distribución ni la columna de ajuste CIF/FOB. Se derivan por la identidad oferta = utilización por producto: el residuo de los productos 4902, 4905, 4907, 5303 y CIF_FOB es ajuste CIF/FOB; el de 4501/4502, márgenes de electricidad; el resto, márgenes de comercio.
   6. `agregar_clasificaciones()`: une por llaves (cuadrante, `Idf_Transaccion`, código de actividad, `Idf_Producto`), nunca por posición. `reportar_sin_mapear()` debe devolver cero filas.
   7. `verificar_condicion_mercado()`: el sufijo M/NM/UFP debe coincidir con la condición.
   8. `completar_cuadrantes()`: arma la rejilla completa filas × columnas por año y rellena con 0; falla si algún valor no cae en la rejilla.
   9. `armar_esquema_pan_scn()`: ordena y renombra al esquema final.
3. `scripts/10-validar-contra-cou-oficial.R` compara con los COU oficiales (`data/cou_oficial`).

### Reglas de clasificación a tener presentes

- **Condición de mercado:** se deriva de la transacción (P00101/P00201/B00101 = Mercado; P00102/P00202/B00102 = Uso final propio; P00103/P00203/B00103 = No de mercado), no del sufijo, para cubrir 49.1 y 50.x, que no traen sufijo. Así 41.1 M y 41.1 NM son la misma actividad con distinta condición.
- **Construcción:** las actividades 36.2 y 36.3 aparecen desde la apertura de 2022 (la Tabla las trae para toda la serie). Heredan la clasificación de 36.1 y están marcadas `revisar = TRUE`: su clasificación bioeconómica está pendiente de confirmar.
- **Consumo final:** ISFLSH y gobierno vienen sin separar individual y colectivo (Tabla). Impuesto a las exportaciones (D.213) en cero.
- **Productos especiales:** `CIF_FOB` y 6701-6704 (compras directas) son filas especiales; `B.1` es valor agregado.

## Validación (script 10)

- **2022-2024:** coincide con los COU oficiales en todas las celdas (diferencia máxima ~1e-8) y en VAB (2024: oferta y utilización 163.657; VAB 84.357).
- **2018-2021:** la Tabla coincide con la base anterior (`salidas/pan_scn.RDS`), pero difiere de los archivos de `data/cou_oficial` (otra revisión). Ejemplo 2021: VAB +213 millones respecto al archivo, consumo final +2,2%. Pendiente de aclarar con el INEC cuál es la versión vigente.
- **Coherencia interna (todos los años):** oferta = utilización por año y producto; VAB = producción - consumo intermedio por actividad y condición.

## Cómo usarla

```r
d <- readRDS("salidas/pan_scn_oficial.RDS")

# Producción por categoría bioeconómica de producto, 2024
d |>
  dplyr::filter(
    `Año` == 2024,
    Cuadro == "01 Oferta",
    `Código área transaccional columnas` == "ATC01"
  ) |>
  dplyr::summarize(
    produccion = sum(Valor),
    .by = `Clasificación Bioeconomía Productos`
  )
```

Notas para el análisis:

- **VAB bioeconómico:** se calcula por categoría de producto como producción (oferta, ATC01) menos consumo intermedio (utilización, ATC01); la categoría la define el producto.
- **Totales oficiales:** para que coincidan con el COU oficial hay que incluir las filas sin clasificación bioeconómica (NA en `Clasificación Bioeconomía Productos`): ajuste CIF/FOB y compras directas (ATF03, ATF04a/b, ATF05a/b). En 2024 las compras directas suman 1.380 de oferta y 18 de consumo intermedio.
- **Filtrar por `Cuadro` y `Código área transaccional columnas`** antes de sumar: el mismo valor no se repite entre cuadros, pero sumar toda la base mezcla oferta y utilización.
- **Series:** son valores a precios corrientes; no hay medidas encadenadas.
