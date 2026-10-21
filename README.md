# Cuenta de Bioeconomía de Panamá

## Descripción general

Este repositorio contiene todo lo necesario para estimar la cuenta satélite de bioeconomía de Panamá a partir de los Cuadros de Oferta y Utilización (COU) del Sistema de Cuentas Nacionales (INEC). Parte de la Tabla plana oficial de cuadros complementarios (2018-2024), le agrega la clasificación bioeconómica de productos y actividades, y produce:

- una base de datos consolidada (`.RDS`, `.xlsx` y DuckDB),
- el COU bioeconómico agregado en Excel, con una hoja por año,
- y el documento final en Word (`documentos/cb-panama.qmd`).

Todos los productos salen de una sola fuente de verdad: `salidas/pan_scn_oficial.RDS`. Cifras en millones de balboas (B/.) a precios corrientes.

## Flujo de trabajo

Ejecutar siempre desde la raíz del proyecto, en este orden:

| Paso | Script | Qué hace |
|---|---|---|
| 1 | `scripts/09a-crear-equivalencias-v03.R` | Construye `data/config/pan_v03_equivalencias.xlsx` (lookups de cuadrantes, transacciones, actividades, filas y columnas). Solo se repite si cambian los lookups. |
| 2 | `scripts/09-procesamiento-tabla-oficial.R` | Procesa la Tabla plana: elimina sumas parciales y totales, deriva márgenes y ajuste CIF/FOB, completa los cuadros y guarda `salidas/pan_scn_oficial.*`. |
| 3 | `scripts/10-validar-contra-cou-oficial.R` | Compara la base con los COU oficiales de `data/cou_oficial`, celda por celda y en agregados. |
| 4 | `scripts/08-exportar-todo-con-funciones.R` | Genera `salidas/COU-BIO-agregado-2018-2024.xlsx`. |
| 5 | `documentos/cb-panama.qmd` | Documento final. Renderizar a Word con `quarto render documentos/cb-panama.qmd --to docx --execute-dir ..` |

Las funciones están en `scripts/00-funciones.R` (procesamiento y validación) y `scripts/00-funciones-exportar-Excel.R` (exportación a Excel). Los scripts `06` y `07` son de exploración y de exportación de un solo año.

## Estructura del repositorio

- `data/config/`: configuración y equivalencias (clasificación bioeconómica, áreas transaccionales, condición de mercado).
- `data/cou_flat/`: Tabla plana oficial (fuente de la base).
- `data/cou_oficial/`: COU oficiales del INEC 2018-2024, usados para validar.
- `documentos/`: documento Quarto, bibliografía y plantilla de Word.
- `salidas/`: base de datos y Excel generados.
- `scripts/`: código del proceso.


## Validación

La base coincide con los COU oficiales de 2022 a 2024 en todas las celdas. Para 2018-2021, la Tabla plana corresponde a una revisión distinta de la de los archivos de `data/cou_oficial`.

## Material del curso

El repositorio incluye además material de un curso práctico de procesamiento de COU en R con tidyverse: los scripts didácticos `01` a `05` (que usan `data/cou`, `data/intro` y `data/ejemplo`) y las presentaciones Quarto en `presentaciones/`.
