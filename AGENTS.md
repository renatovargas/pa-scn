# Memoria de trabajo: cuenta de bioeconomía de Panamá (pa-scn)

Repositorio de Renato Vargas (consultor CEPAL). Procesa los Cuadros de Oferta y Utilización (COU) de Panamá, les agrega la clasificación bioeconómica y produce una base de datos, Excel y un documento Word. Idioma de trabajo: español. Código con tidyverse y pipe nativo `|>`.

## Flujo vigente (fuente de verdad: la Tabla plana oficial)

| Script | Qué hace |
|---|---|
| `scripts/00-funciones.R` | Funciones del pipeline. Incluye las de la Tabla plana (`leer_tabla_oficial`, `filtrar_datos_individuales`, `derivar_ajustes_oferta`, `completar_cuadrantes`, etc.) y las de validación (`leer_cou_oficial`, `armonizar_llaves`). |
| `scripts/09a-crear-equivalencias-v03.R` | Construye `data/config/pan_v03_equivalencias.xlsx` (hojas `cuadrantes`, `transacciones`, `actividades`, `filas`, `columnas`). Correr antes del 09 si cambian los lookups. |
| `scripts/09-procesamiento-tabla-oficial.R` | Tabla plana -> `salidas/pan_scn_oficial.RDS` (+ `.xlsx` y tabla `pan_scn_oficial` en `salidas/pan_scn.duckdb`). |
| `scripts/10-validar-contra-cou-oficial.R` | Compara la base con `data/cou_oficial` celda por celda y en agregados. |
| `scripts/06`, `07`, `08` | Exploración y Excel de COU bioeconómico agregado; leen `pan_scn_oficial.RDS`. El 08 genera `salidas/COU-BIO-agregado-2018-2024.xlsx`. El 07 es la versión de un solo año (2022). |
| `documentos/cb-panama.qmd` | Documento final (entregable: el `.docx`). Lee `salidas/pan_scn_oficial.RDS`. |

Los scripts 01-05 son didácticos (curso) y usan `data/cou` (2015-2022) con la config `pan_config.xlsx` y las equivalencias `pan_v02`. Siguen funcionando, pero `salidas/pan_scn.RDS` es la base anterior (revisión vieja de 2018-2022).

Ejecutar siempre desde la raíz del proyecto. Renderizar el documento con `quarto render documentos/cb-panama.qmd --to docx --execute-dir ..` desde `documentos/`. Borrar el HTML y `_files` si se generan.

## Datos

- `data/cou_flat/...Cuadros complementarios... 2018-24.xlsx`: hoja `Tabla` (69.274 filas: Año, Idf_Transaccion, Idf_Actividad, Idf_Categoria, Idf_Producto, Valor, Cou) y `Diccionario` (3 bloques). Es la fuente de la base. `Año` viene como texto ("2024 (P)" provisional; "2025 (E)" tiene 2 filas y se excluye).
- `data/cou_oficial/`: 7 COU del INEC 2018-2024 (Oferta y Utilización). 2018-2021 tienen 110 columnas; 2022-2024, 113 (la construcción se abre en 36.1, 36.2, 36.3). Se usan solo para validar.
- Unidades: millones de B/. a precios corrientes.

## Reglas de la Tabla plana (verificadas)

- Solo `Cou == "C"`. Se eliminan los totales (P001, P002, D0021, P006, P007), las filas con `Idf_Producto == "00"` (total de la actividad; duplican valores) y variables fuera del SCN (empleo, remuneraciones, IPC, FBK, encadenados, etc.). La jerarquía se prueba con `verificar_totales()` (diferencia cero).
- Cuadro, cuadrante y transacción salen del lookup `transacciones` (llave `Idf_Transaccion`). Producto por `Idf_Producto` (4 dígitos; `CIF_FOB` y `6701`-`6704` son filas especiales; `B.1` es valor agregado).
- Condición de mercado: se deriva de la transacción (P00101/P00201/B00101 = Mercado; 02 = Uso final propio; 03 = No de mercado), no solo del sufijo M/NM/UFP. 49.1 y 50.x no traen sufijo.
- Actividades 36.2 y 36.3 son nuevas respecto a v02; se heredan de 36.1 y están marcadas `revisar = TRUE` en la hoja `actividades`. Pendiente de confirmar su clasificación bioeconómica.
- La Tabla no trae márgenes de distribución ni ajuste CIF/FOB. Se derivan por identidad oferta = utilización por producto (`derivar_ajustes_oferta()`): el residuo de 4902, 4905, 4907, 5303 y CIF_FOB es ajuste CIF/FOB; 4501/4502 son márgenes de electricidad; el resto, márgenes de comercio. Reproduce exacto el COU oficial 2022-2024.
- La Tabla solo trae celdas distintas de cero; `completar_cuadrantes()` arma la rejilla completa con ceros. La columna D.213 (impuesto a exportaciones) queda en cero.
- ISFLSH y gobierno vienen sin separar consumo individual/colectivo.
- Códigos de fila y columna nuevos: `pan_v03_q0X_f####` / `_c####` (generados por orden, no posicionales).

## Resultados de validación (script 10)

- 2022-2024: coinciden con el COU oficial en todas las celdas (diferencia máxima ~1e-8) y en VAB.
- 2018-2021: la Tabla coincide con la base anterior (`pan_scn.RDS`), pero difiere de los archivos de `cou_oficial` (otra versión/revisión). Ejemplo 2021: VAB +213 millones, consumo final +2,2%, FBK -3,3%. Pendiente de aclarar con el INEC cuál es la versión vigente.
- Coherencia interna: oferta = utilización por año y producto; VAB = producción - consumo intermedio por actividad.
- Las filas sin clasificación bioeconómica (ajuste CIF/FOB y compras directas 67xx) se muestran en el documento como renglones propios, para que los totales coincidan con el COU oficial y el Excel (2024: oferta y utilización 163.657; VAB 84.357). En el setup, `Clasificación Bioeconomía Productos` toma los valores `cat_cif` ("Ajuste CIF/FOB") y `cat_compras` ("Compras directas (exterior y territorio)", suma de ATF04a/b y ATF05a/b); `niveles_cat` = las 3 categorías bio + esas dos. Tablas 2-5 y `cifras_texto` usan `niveles_cat`; figuras, tabla 1, manufactura e impuestos usan solo `bio_levels`. El renglón CIF/FOB solo aparece en la tabla de oferta. Las compras directas aportan 18 de consumo intermedio (VAB -18) y 1.380 de oferta.

## Esquema de `pan_scn_oficial.RDS`

35 columnas: las 33 de `pan_scn.RDS` (Filas, Columnas, Valor, Año, Cuadro, Cuadrante, Unidades, Precios, clasificaciones de columnas y de filas) más `Condición de Mercado` y `Estatus` (Definitivo, P). Cuadros: `01 Oferta`, `02 Utilización`, `03 Valor Agregado`. Códigos de área transaccional de columnas: ATC01 producción/CI, ATC02 exportaciones/importaciones, ATC03 CIF/FOB, ATC04 impuestos y subvenciones, ATC05 márgenes, ATC06 consumo final, ATC07 formación de capital.

## Documento (`cb-panama.qmd`)

- El chunk `setup` renombra columnas a los nombres del documento original (`year`, `value`, `tabla_destino`, `Área transaccional columnas No.`, `Transacciones Agregadas`). Año de referencia dinámico: `anio_ref`, `anio_ini`. Las cifras del texto son inline R (`cifra()`, `fmt1()`, `fmt_num()`); no escribir números a mano.
- Quarto 1.10 genera para Word tablas y figuras con título (`tbl-`/`fig-`) dentro de una tabla contenedora con XML duplicado: Word pide reparar el archivo y las columnas se aplastan. Por eso NO se usan `tbl-cap`, `fig-cap`, `tbl-` ni `fig-` en los labels. Los títulos se escriben con `titulo_tabla()` / `titulo_figura()` (estilos "Table Caption" / "Image Caption") y la numeración está fija en `tablas_num` y `figuras_num` del `setup`; hay que actualizarla si se agregan o reordenan tablas. Las referencias son inline: `` `r ref_tabla("oferta")` ``.
- Tablas con `mostrar_tabla()` (flextable, 9 pt, Aptos, total en negrita). Los chunks de tabla usan `results: asis`. Todo el documento va en vertical; los márgenes (0,75" laterales, 1" arriba y abajo) vienen de `custom-reference-doc.docx`, así que el ancho útil es 7" (`ancho = 7`). Las tablas 1 y 3 usan `rotar_encabezado = TRUE` (encabezados de sectores a 90 grados).
- Cada render sobrescribe `documentos/cb-panama.docx` y no conserva la carátula ni el disclaimer: el usuario pega el contenido en su versión con carátula. No editar ese archivo a mano; guardar la versión final con otro nombre.
- `lang: es` en el YAML (si no, salen "Figure"/"Table").
- Etiquetas de los datos: `Transacciones Agregadas` usa "Subvenciones" (no "Subvenciones a los productos"; el filtro anterior nunca coincidía y los impuestos "netos" eran brutos).
- Se quitó la lectura de `material/Figuras.xlsx` (no existe; no se usaba).
- Tablas actuales: 1 producción por grupo de sectores, 2 oferta total, 3 consumo intermedio, 4 utilización total (usos), 5 VAB, 6 manufactura (6 actividades), 7 impuestos, 8 serie temporal. Un `stopifnot` verifica que utilización total = oferta total.
- El 60,8% de bioeconomía en manufactura (2024) lo explican seis actividades agroindustriales (carne, otros alimentos, molinería, pescado, bebidas, lácteos). Depende de la clasificación de pocos productos.
- Hallazgo 2020: la participación de la bioeconomía directa en el VAB sube (4,1% -> 6,5%) y la de la extendida baja (4,9% -> 3,4%); cifras a precios corrientes.

## Preferencias del usuario

- Respuestas concisas, en español; pedir confirmación antes de decisiones de clasificación.
- Funciones con nombres claros en español y scripts "paso a paso" estilo `05-procesamiento-con-funciones.R`.
- No es necesaria la salida HTML; el entregable es el Word.
- `duckdb` está instalado. Python: no hay `python-docx`; la revisión del docx se hizo descomprimiendo el XML.
