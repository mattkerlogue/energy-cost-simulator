
# energy_cost_simulator

<!-- badges: start -->
<!-- badges: end -->

This repo contains the code for a 
[simple calculator](https://mattkerlogue.github.io/energy-cost-simulator/)
for estimating monthly energy prices in the UK from October 2022 to 
September 2023.

## Purpose
On Friday 26 August 2021 Ofgem, the UK energy regulator, 
[announced a rise](https://www.theguardian.com/money/2022/aug/26/ofgem-raises-energy-price-cap-to-3549) 
in the price cap for domestic energy. On the same day, energy consultancy
[Cornwall Insight released updated forecasts](https://twitter.com/faisalislam/status/1563049747354910720) 
for the future values of Ofgem's price cap in 2023 showing massive increases in
household bills.

Reporting on the price cap has largely been focussed on the estimate of the 
annual cost for the "average" domestic customer, which for the new price cap is 
estimated as £3,549. While averages can be useful indicators they do not help
customers understand their own situation. Similarly, the annual figure does not
necessarily help customers understand their potential costs, especially as we
head into the most energy intensive period of the year, and have significant
increases forecast in the price cap going forward.

This calculator provides a simple approach to estimate energy costs using Ofgem's
announced price cap for October 2022 to December 2022 and Cornwall Insight's
forecasts of changes to the price cap for January 2023 through to September 2023.


## Contents

The calculator is composed of two main stages:

- processing of UK energy statistics in R to build the basics of the simulator - 
  (`energy_cost_simulation.R`)[energy_cost_simulation.R]
- an interactive calculator built in Quarto for end-users -
  (`index.qmd`)[index.qmd]
  ([live version](https://mattkerlogue.github.io/energy-cost-simulator/))

## Data

The simulator uses the following sources:

- the UK Department for Business, Energy and Industrial Strategy's 
  *Energy Trends* statistics, specifically 
  [table 4.2](https://www.gov.uk/government/statistics/gas-section-4-energy-trends) 
  and [table 5.5](https://www.gov.uk/government/statistics/electricity-section-5-energy-trends)
- Ofgem's published [default tariff price cap model](https://www.ofgem.gov.uk/publications/default-tariff-cap-level-1-october-2022-31-december-2022)
- future forecasts of the Ofgem price cap [produced by Cornwall Insight](https://www.cornwall-insight.com/press/cornwall-insight-comments-on-the-announcement-of-the-october-price-cap/), as 
[quoted on Twitter by Faisal Islam](https://twitter.com/faisalislam/status/1563049747354910720) (Economics Editor, BBC News) and [reported in The Guardian](https://www.theguardian.com/money/2022/aug/26/ofgem-raises-energy-price-cap-to-3549)

The statistics from BEIS and the Ofgem price cap are stored as Excel spreadsheets 
in the [`data`](data/) folder of this repository.

Outputs of the data analysis and modelling in R, which are used as inputs to the
Quarto document, are stored as CSV files in the [`data`](data/) folder of this
repository.

## Copyright and licensing

The code contained in this repository is released under the [MIT License](LICENSE.md).

The data from BEIS and Ofgem is provided via the [Open Government Licence](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
The  figures from [Cornwall Insight](https://www.cornwall-insight.com/) are their
proprietary information that has been made publicly available via a press 
release, and is used here for non-commercial research purposes.