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
  tidyr::pivot_longer(cols = c(elec_twh, gas_gwh), names_to = "fuel", 
                      values_to = "consumption") |>
  dplyr::mutate(fuel = if_else(fuel == "elec_twh", "electricity", "gas")) |>
  dplyr::filter(year >= 2010 & year < 2022) |>
  dplyr::group_by(fuel, year) |>
  dplyr::mutate(
    # calculate relative trend
    relative_value = consumption / max(consumption)
  ) |>
  dplyr::ungroup()

# generate monthly average for each fuel
energy_trend_summary <- energy_trends |>
  dplyr::select(month, fuel, relative_value) |>
  dplyr::group_by(fuel, month) |>
  dplyr::summarise(value = mean(relative_value), .groups = "drop_last") |>
  dplyr::mutate(
    value = value/max(value),   # normalise average
    prop = value/sum(value)     # calculate month's contribution to annual total
  )

# dataset for graphing
energy_trends_gdt <- energy_trends |>
  dplyr::select(ref_month, year, month, fuel, value = relative_value)

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
#   - gas: ??1,875 (incl VAT) + ??104 standing charge
#   - electricity: ??1,778 (incl VAT) + ??169 standing charge

# Cornwall Insight figures quoted in The Guardian
# https://www.theguardian.com/money/2022/aug/26/ofgem-raises-energy-price-cap-to-3549
# https://twitter.com/faisalislam/status/1563049747354910720
# 
# annual cap figures:
#   - ??5,387 for Jan 2023 to Mar 2023
#   - ??6,616 for Apr 2023 to Jun 2023
#   - ??5,897 for Jul 2023 to Sep 2023
# 
# use Ofgem default tarrif cap model to convert cap to price per kWh:
# https://www.ofgem.gov.uk/publications/default-tariff-cap-level-1-october-2022-31-december-2022
#   - Ofgem price cap methodology implies 48.7% electricity / 51.3% gas split 
#     in costs between the two fuels
#   - Ofgem price cap methodology assumes 3,100 kWh electricity & 12,000 kWh gas
cap_estimates <- tibble::tibble(
  month = c(10:12, 1:3, 4:6, 7:9),
  cap_forecast = c(rep(NA_real_, 3), rep(5387, 3), rep(6616, 3), rep(5897, 3)),
  electricity = 0.487 * cap_forecast / 3100,
  gas = 0.513 * cap_forecast / 12000
) |>
  mutate(
    electricity = if_else(month %in% 10:12, (1778 + 169) / 3100, electricity),
    gas = if_else(month %in% 10:12, (1875 + 104) / 12000, gas)
  )

# simulate costs for coming year
cost_simulator <- tibble::tibble(
  # set-up simulator for Oct 2022 to September 2023
  year = rep(c(rep(2022, 3), rep(2023, 9)), 2),
  month = rep(c(10:12, 1:9), 2),
  fuel = sort(rep(c("electricity", "gas"), 12))
) |>
  dplyr::left_join(
    # merge monthly usage proportion
    energy_trend_summary, by = c("month", "fuel")
  ) |>
  dplyr::left_join(
    # merge kwh cost estimates
    cap_estimates |> 
      dplyr::select(-cap_forecast) |> 
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
  dplyr::select(ref_month, fuel, default_cost) |>
  tidyr::pivot_wider(names_from = fuel, values_from = default_cost) |>
  dplyr::mutate(
    total = electricity + gas
  )

# plot costs
default_costs_plot <- ggplot(cost_simulator, aes(x = ref_month, y = default_cost, fill = fuel)) +
  geom_col() +
  geom_text(
    mapping = aes(y = default_cost, colour = fuel,
                  label = scales::dollar(default_cost, prefix = "??", accuracy = 1)),
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
                  label = scales::dollar(total, prefix = "??", accuracy = 1)),
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
    geom = "text", x = as.Date("2022-12-12"), y = 725, 
    label = "Ofgem cap ?????????", size = 3,
    family = "Hack", colour = "grey40", hjust = 1
  ) +
  annotate(
    geom = "text", x = as.Date("2022-12-20"), y = 725, 
    label = "?????? Cornwall Insight cap forecast", size = 3,
    family = "Hack", colour = "grey40", hjust = 0
  ) +
  scale_y_continuous(limits = c(0, 725), breaks = seq(0, 650, 50)) +
  scale_x_date(date_labels = "%b-%y", date_breaks = "1 month", 
               expand = expansion()) +
  scale_fill_manual(values = energy_colours, labels = c("Gas", "Electricity")) +
  scale_colour_manual(values = c("gas" = "grey90", "electricity" = "grey50")) +
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


flat_assumption <- cap_estimates |>
  mutate(
    default_elec = electricity * 3100/12,
    default_gas = gas * 12000/12,
    default_total = default_elec + default_gas,
    my_elec = electricity * 2200/12,
    my_gas = gas * 8200/12,
    my_total = my_elec + my_gas
  ) |>
  select(month, starts_with("default"), starts_with("my"))
