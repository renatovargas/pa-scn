## Datos

# Primero llamamos las librerías necesarias.

library(tidyverse)
library(gt)
# library(pivottabler)

rm(list = ls())
# Seguidamente, importamos los datos de la cuenta de Bioeconomía.

pan_scn <- readRDS("salidas/pan_scn.RDS")


# Y probamos hacer un resumen para una actividad económica en particular.

test <- pan_scn |>
  filter(
    Año == 2022 &
      Valor > 0 &
      Cuadro %in% c("01 Oferta", "02 Utilización") &
      `Área transaccional columnas` == "Producción / Consumo intermedio" &
      `Descripción Actividades` ==
        "Fabricación de sustancias y productos químicos" &
      !is.na(`Nomenclatura Local de Productos`)
  ) |>
  summarize(
    Valor = sum(Valor, na.rm = T),
    .by = c(
      Cuadro,
      `Código Nomenclatura Local de Productos`,
      `Nomenclatura Local de Productos`,
      `Clasificación Bioeconomía Productos`
    )
  ) |>
  mutate(
    Porcentaje = Valor / sum(Valor) * 100,
    .by = Cuadro
  ) |>
  arrange(Cuadro, desc(Valor)) |>
  ungroup()


test |>
  gt() |>
  fmt_number(
    columns = Valor,
    decimals = 1,
    use_seps = TRUE
  ) |>
  fmt_number(
    columns = Porcentaje,
    decimals = 2
  )

test2 <- pan_scn |>
  filter(
    Año == 2022 &
      Valor > 0 &
      Cuadro == "02 Utilización" &
      `Área transaccional columnas` == "Producción / Consumo intermedio" &
      # Actividades de interés
      `Código Clasificación Actividades` %in%
        c("14.1", "19.2", "23.1", "21.1", "36.1", "26.1") &
      !is.na(`Clasificación Bioeconomía Productos`)
  ) |>
  select(
    `Descripción Actividades`,
    `Clasificación Bioeconomía Productos`,
    Valor
  ) |>
  group_by(`Descripción Actividades`, `Clasificación Bioeconomía Productos`) |>
  summarize(Valor = sum(Valor, na.rm = T)) |>
  mutate(
    Pct = Valor * 100 / sum(Valor),
    Pct_label = paste0(sprintf("%.2f", Pct), "%")
  ) |>
  rename(
    Actividades = `Descripción Actividades`,
    Insumos = `Clasificación Bioeconomía Productos`,
    Valor = Valor
  ) |>
  ungroup()

test3 <- test2[test2$Insumos == "Bioeconomía", ] |>
  arrange(desc(Pct))

test2$Actividades <- factor(test2$Actividades, levels = test3$Actividades)
test2$Insumos <- fct_relevel(
  test2$Insumos,
  "No bioeconomía",
  "Bioeconomía extendida",
  "Bioeconomía"
)

# Grafico
ggplot(
  test2,
  aes(
    x = Actividades,
    y = Valor,
    fill = Insumos
  )
) +
  geom_bar(
    stat = "identity",
    position = "fill"
  ) +
  geom_text(
    aes(label = paste0(sprintf("%1.1f", Pct), "%")),
    position = position_fill(vjust = 0.5),
    colour = "black",
    size = 3
  ) +
  ylab("Porcentaje") +
  xlab("Actividades económicas") +
  labs(fill = "Insumos") +
  # theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
  scale_x_discrete(
    labels = c(
      "Carne",
      "Servicio de \nalimentos",
      "Muebles",
      "Textiles",
      "Construcción",
      "Químicos"
    )
  )
