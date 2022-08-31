library(tidyverse)

# UK Energy Trends (Gas), Table 4.2
# Department for Business, Energy & Industrial Strategy, July 2022
# https://www.gov.uk/government/statistics/gas-section-4-energy-trends

# UNCOMMENT TO DOWNLOAD FILE 
# download.file(
#   "https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/1100121/ET_4.2_AUG_22.xlsx",
#   "data/ET_4.2_AUG_22.xlsx"
# )

et_42_gas <- readxl::read_excel(
  path = "data/ET_4.2_AUG_22.xlsx",
  sheet = "Month (GWh)"
)

# UK Energy Trends (Electricity), Table 5.5
# Department for Business, Energy & Industrial Strategy, July 2022
# https://www.gov.uk/government/statistics/electricity-section-5-energy-trends

# UNCOMMENT TO DOWNLOAD FILE 
# download.file(
#   "https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/1100102/ET_5.5_AUG_22.xlsx",
#   "data/ET_5.5_AUG_22.xlsx"
# )

et_55_elec <- readxl::read_excel(
  path = "data/ET_5.5_AUG_22.xlsx",
  sheet = "Month"
)

# extract gas output statistics
# correct double space in Nov 2006 label
gas_output <- et_42_gas[7:nrow(et_42_gas), c(1, 17)]
names(gas_output) <- c("ref_month", "gas_gwh")
gas_output <- gas_output |> 
  dplyr::mutate(ref_month = stringr::str_replace(ref_month, "  ", " "))

# extract electricity consumption
elec_consumption <- et_55_elec[6:nrow(et_55_elec), c(1, 16)]
names(elec_consumption) <- c("ref_month", "elec_twh")

# combine and process data
# calculate monthly rhythm figure
energy_trends <- elec_consumption |>
  dplyr::full_join(gas_output, by = "ref_month") |>
  dplyr::mutate(
    ref_month = lubridate::my(ref_month),
    month = lubridate::month(ref_month),
    year = lubridate::year(ref_month),
    across(c(elec_twh, gas_gwh), as.numeric)
  ) |>
  dplyr::filter(year >= 2010 & year < 2022) |>
  dplyr::group_by(year) |>
  dplyr::mutate(
    # calculate relative trend
    electricity_trend = elec_twh / max(elec_twh),
    gas_trend = gas_gwh / max(gas_gwh)
  ) |>
  dplyr::ungroup()

# generate monthly average for each fuel
energy_trend_summary <- energy_trends |>
  dplyr::select(month, electricity_trend, gas_trend) |>
  tidyr::pivot_longer(cols = -month, names_to = "fuel") |>
  dplyr::group_by(fuel, month) |>
  dplyr::summarise(value = mean(value), .groups = "drop_last") |>
  dplyr::mutate(
    fuel = stringr::str_remove_all(fuel, "_trend"),
    value = value/max(value),   # normalise average
    prop = value/sum(value)     # calculate month's contribution to annual total
  )

# dataset for graphing
energy_trends_gdt <- energy_trends |>
  dplyr::select(ref_month, year, month, electricity_trend, gas_trend) |>
  tidyr::pivot_longer(cols = c(electricity_trend, gas_trend), 
                      names_to = "fuel") |>
  dplyr::mutate(fuel = stringr::str_remove_all(fuel, "_trend"))

energy_colours <- c(
  "electricity" = "#E8C027",
  "gas" = "#1092E8"
)

# graph
uk_energy_plot <- ggplot(energy_trends_gdt, aes(x = month, y = value, colour = fuel, 
                              shape = fuel)) +
  geom_point() +
  geom_smooth(se = FALSE) +
  # geom_line(data = energy_trend_summary, colour = "grey40", linetype = "dashed") +
  facet_wrap(~fuel, nrow = 1) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2), labels = scales::percent_format()) +
  scale_x_continuous(
    breaks = 1:12, 
    labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")
  ) +
  scale_color_manual(values = energy_colours) +
  labs(
    title = "UK energy usage",
    y = "relative monthly energy use"
  ) +
  mattR::theme_lpsdgeog() +
  theme(
    panel.grid.minor.x = element_blank(),
    legend.position = "none"
  )

write_csv(energy_trends_gdt, "data/energy_trends.csv")

# current cap estimates
# 
# use Ofgem default tarrif cap model for October to December
# https://www.ofgem.gov.uk/publications/default-tariff-cap-level-1-october-2022-31-december-2022
#   - gas: £1,875 (incl VAT)
#   - electricity: £1,778 (incl VAT)

# Cornwall Insight figures quoted in The Guardian
# https://www.theguardian.com/money/2022/aug/26/ofgem-raises-energy-price-cap-to-3549
# https://twitter.com/faisalislam/status/1563049747354910720
# 
# annual cap figures:
#   - £5,387 for Jan 2023 to Mar 2023
#   - £6,616 for Apr 2023 to Jun 2023
#   - £5,897 for Jul 2023 to Sep 2023
# 
# use Ofgem default tarrif cap model to convert cap to price per kWh:
# https://www.ofgem.gov.uk/publications/default-tariff-cap-level-1-october-2022-31-december-2022
#   - Ofgem price cap methodology implies 48.7% electricity / 51.3% gas split 
#     in costs between the two fuels
#   - Ofgem price cap methodology assumes 3,100 kWh electricity & 12,000 kWh gas
cap_estimates <- tibble::tibble(
  month = c(10:12, 1:3, 4:6, 7:9),
  cap = c(rep(0, 3), rep(5387, 3), rep(6616, 3), rep(5897, 3)),
  electricity = 0.487 * cap / 3100,
  gas = 0.513 * cap / 12000
) |>
  mutate(
    electricity = if_else(month %in% 10:12, 1778 / 3100, electricity),
    gas = if_else(month %in% 10:12, 1875 / 12000, gas)
  )

# simulate costs for coming year
cost_simulator <- tibble::tibble(
  # set-up simulator for Oct to 
  year = rep(c(rep(2022, 3), rep(2023, 9)), 2),
  month = rep(c(10:12, 1:3, 4:6, 7:9), 2),
  fuel = sort(rep(c("electricity", "gas"), 12))
) |>
  dplyr::left_join(
    # merge monthly usage proportion
    energy_trend_summary, by = c("month", "fuel")
  ) |>
  dplyr::left_join(
    # merge kwh cost estimates
    cap_estimates |> 
      dplyr::select(-cap) |> 
      tidyr::pivot_longer(cols = -month, names_to = "fuel", 
                          values_to = "cap"),
    by = c("month", "fuel")
  ) |>
  dplyr::mutate(
    # estimate usage for default
    default_usage = if_else(
      fuel == "electricity",
      prop * 3100,
      prop * 12000
    ),
    # estimate cost for default
    default_cost = cap * default_usage,
    # estimate monthly usage based on my annual total
    my_usage = if_else(
      fuel == "electricity",
      prop * 2200,
      prop * 8200
    ),
    # estimate montly cost based on my estimated usage
    my_cost = cap * my_usage,
    ref_month = lubridate::ym(paste(year, month, sep = "-"))
  )

# get my estimate costs
month_totals <- cost_simulator |>
  dplyr::select(ref_month, fuel, my_cost) |>
  tidyr::pivot_wider(names_from = fuel, values_from = my_cost) |>
  dplyr::mutate(
    total = electricity + gas
  )

# plot costs
my_costs_plot <- ggplot(cost_simulator, aes(x = ref_month, y = my_cost, fill = fuel)) +
  geom_col() +
  geom_text(
    mapping = aes(y = my_cost, colour = fuel,
                  label = scales::dollar(my_cost, prefix = "£", accuracy = 1)),
    position = position_stack(vjust = 0.05),
    size = 3,
    angle = 90,
    hjust = 0,
    family = "Hack",
    fontface = "bold",
    show.legend = FALSE
  ) +
  geom_text(
    data = month_totals,
    mapping = aes(y = total, x = ref_month,
                  label = scales::dollar(total, prefix = "£", accuracy = 1)),
    inherit.aes = FALSE,
    size = 3,
    angle = 90,
    hjust = 0,
    nudge_y = 10,
    family = "Hack",
    colour = "grey40",
    fontface = "bold"
  ) +
  geom_vline(xintercept = as.Date("2022-12-16"), colour = "grey40", 
             linetype = "dashed") +
  annotate(
    geom = "text", x = as.Date("2022-12-12"), y = 545, 
    label = "Ofgem cap ︎◀︎", size = 3,
    family = "Hack", colour = "grey40", hjust = 1
  ) +
  annotate(
    geom = "text", x = as.Date("2022-12-20"), y = 545, 
    label = "▶︎ Cornwall Insight forecast", size = 3,
    family = "Hack", colour = "grey40", hjust = 0
  ) +
  scale_y_continuous(limits = c(0, 545), breaks = seq(0, 450, 50)) +
  scale_x_date(date_labels = "%b-%y", date_breaks = "1 month", 
               expand = expansion()) +
  scale_fill_manual(values = energy_colours, labels = c("Electricity", "Gas")) +
  scale_colour_manual(values = c("electricity" = "grey50", "gas" = "grey90")) +
  labs(
    title = "Forecast monthly energy costs",
    x = "Month",
  ) +
  mattR::theme_lpsdgeog() +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.text.x = element_text(angle = 90),
    axis.text.y = element_blank(),
    axis.title.y = element_blank(),
    legend.position = "bottom",
    legend.title = element_blank()
  )

simulator_out <- cost_simulator |>
  select(-my_usage, -my_cost)

write_csv(simulator_out, "data/cost_simulator.csv")
