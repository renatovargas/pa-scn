# Curso práctico de procesamiento y exportación de Cuadros de Oferta y Utilización Bioeconómicos en R

## Descripción general

Este repositorio contiene los materiales y scripts utilizados en un curso práctico de aprendizaje por medio de la práctica (*aprender-haciendo*) enfocado en el procesamiento, transformación, análisis y exportación de Cuadros de Oferta y Utilización (COU) bioeconómicos utilizando R y el ecosistema tidyverse.

El objetivo principal del curso es demostrar cómo transformar datos de cuentas nacionales originalmente estructurados para análisis estadístico en productos reproducibles, transparentes y visualmente publicables, manteniendo una lógica clara y fácil de enseñar.

El flujo de trabajo cubre:

- Introducción a R y estructuras básicas de datos.
- Importación de datos desde múltiples formatos.
- Introducción al ecosistema tidyverse.
- Procesamiento de Cuadros de Oferta y Utilización.
- Conversión de matrices a formato plano.
- Agregar el tema bioeconómico a los datos.
- Construcción de bases de datos económicas reproducibles.
- Uso de funciones para automatizar procesos.
- Análisis exploratorio de datos.
- Exportación avanzada a Excel utilizando `openxlsx`.
- Generación automatizada de cuadros institucionales multi-año.

El repositorio busca equilibrar:

- claridad pedagógica,
- reproducibilidad,
- automatización,
- y generación de productos compatibles con los estándares de trabajo de bancos centrales, institutos nacionales de estadística y ministerios.

---

# Estructura del repositorio

## `data/`

Contiene los datos utilizados durante el curso.

### `data/config/`

Archivos de configuración y equivalencias utilizados para interpretar filas y columnas de los COU.

### `data/cou/`

Archivos originales de Cuadros de Oferta y Utilización.

### `data/ejemplo/`

Datos simplificados utilizados para ejemplos y ejercicios prácticos.

### `data/intro/`

Archivos utilizados durante las sesiones introductorias del curso.

Incluye ejemplos de:

- CSV,
- Excel,
- SPSS,
- STATA,
- y datos geográficos.

---

## `presentaciones/`

Presentaciones del curso en formato Quarto (`.qmd`).

Estas presentaciones acompañan las sesiones prácticas y explican:

- conceptos económicos,
- estructuras de datos,
- tidyverse,
- procesamiento matricial,
- diseño de bases de datos,
- y automatización de flujos de trabajo.

---

## `salidas/`

Contiene los productos generados por los scripts.

Ejemplos:

- archivos `.xlsx`,
- archivos `.RDS`,
- cuadros procesados,
- y exportaciones finales.

---

## `scripts/`

Contiene los scripts principales del curso.

Los scripts están organizados numéricamente para facilitar:

- su ejecución secuencial,
- su explicación en clase,
- y el seguimiento progresivo de conceptos.

---

# Qué se aprende con cada script

## `01-instalar-paquetes.R`

Introducción a la instalación y gestión básica de paquetes en R.

### Conceptos principales

- instalación de paquetes,
- configuración básica del entorno,
- paquetes fundamentales para análisis macroeconómico,
- y preparación del entorno de trabajo.

---

## `02-introduccion.R`

Introducción a R y estructuras básicas de datos.

### Conceptos principales

- objetos,
- vectores,
- matrices,
- data frames,
- índices,
- funciones,
- concatenación de cadenas,
- y lógica básica de programación.

---

## `03-datos-y-tidyverse.R`

Introducción a importación de datos y tidyverse.

### Conceptos principales

- lectura de CSV y Excel,
- importación de SPSS y STATA,
- lectura de datos geográficos,
- visualización simple de mapas,
- uso de `dplyr`,
- uso de `tidyr`,
- uso de `stringr`,
- y flujos de trabajo con tuberías (`|>`).

---

## `04-procesamiento-simple.R`

Procesamiento manual de un Cuadro de Oferta y Utilización sin utilizar funciones.

### Conceptos principales

- lectura de matrices económicas,
- creación de identificadores estables,
- limpieza de datos,
- conversión de matrices a formato largo,
- uso de `pivot_longer()`,
- uniones con tablas de equivalencias,
- y exportación básica a Excel.

---

## `05-procesamiento-con-funciones.R`

Procesamiento automatizado de COU utilizando funciones reutilizables.

### Conceptos principales

- modularización del código,
- automatización iterativa,
- procesamiento multi-cuadrante,
- manejo de configuraciones,
- uso de listas,
- y construcción de bases de datos consolidadas.

---

## `06-analisis-exploratorio.R`

Análisis exploratorio de datos utilizando la base procesada.

### Conceptos principales

- filtrado de información económica,
- agregación de datos,
- cálculo de porcentajes,
- generación de tablas,
- uso de `gt`,
- gráficos con `ggplot2`,
- y análisis de relaciones bioeconómicas.

---

## `07-exportar-cous-Excel.R`

Construcción y exportación de un cuadro bioeconómico agregado a Excel.

### Conceptos principales

- uso de `pivot_wider()`,
- construcción de encabezados jerárquicos,
- generación de matrices económicas,
- estilos avanzados con `openxlsx`,
- bordes jerárquicos,
- agrupaciones visuales,
- subtotales,
- y diseño institucional de cuadros estadísticos.

---

## `08-exportar-todo-con-funciones.R`

Automatización multi-año de la exportación de cuadros bioeconómicos.

### Conceptos principales

- iteración sobre múltiples años,
- generación dinámica de hojas de Excel,
- reutilización de funciones,
- automatización de exportaciones,
- y construcción de productos reproducibles multi-año.

---

# Scripts de funciones

## `00-funciones.R`

Contiene funciones auxiliares utilizadas para el procesamiento de datos.

### Conceptos principales

- separación entre lógica y ejecución,
- reutilización de código,
- funciones parametrizadas,
- procesamiento de cuadrantes,
- lectura de configuraciones,
- y construcción de flujos reproducibles.

---

## `00-funciones-exportar-Excel.R`

Contiene funciones dedicadas a la exportación y formateo avanzado de cuadros en Excel.

### Conceptos principales

- encapsulamiento de lógica de exportación,
- automatización de estilos,
- generación de cuadros institucionales,
- manejo avanzado de `openxlsx`,
- formatos jerárquicos,
- subtotales automáticos,
- exportación multi-hoja,
- y construcción de productos listos para publicación.

---

# Filosofía del curso

Este curso busca enseñar procesamiento de información macroeconómica de forma práctica y aplicada para agregar el tema de la bioeconomía a las cuentas nacionales.

El énfasis no está únicamente en escribir código, sino en desarrollar:

- estructuras reproducibles,
- flujos transparentes,
- productos compatibles con necesidades institucionales,
- y herramientas mantenibles por equipos técnicos.

El objetivo final es que las y los participantes puedan:

- comprender completamente el flujo de transformación,
- adaptar los scripts a sus propias necesidades,
- automatizar procesos repetitivos,
- y producir cuadros estadísticos de alta calidad de manera reproducible.