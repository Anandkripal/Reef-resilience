# Reef Resilience: Environmental Drivers of Great Barrier Reef Benthic Composition

## Overview

This project investigates how environmental conditions influence **hard coral** and **algae cover** across the **Great Barrier Reef (GBR)**.

The analysis combines long-term reef observations with eReefs environmental data to explore relationships between benthic composition and environmental variables including:

- Temperature
- Salinity
- Dissolved oxygen
- Chlorophyll-a
- Suspended solids
- Alkalinity

The project includes data preparation, spatial data integration, predictive modelling, model interpretation using SHAP values, and an interactive **R Shiny dashboard** for exploring reef conditions and model predictions.

---

## Project Objectives

The main objectives of this project are to:

1. Prepare and clean historical reef benthic-cover observations.
2. Extract environmental variables from annual eReefs NetCDF datasets.
3. Spatially match reef observations with the nearest environmental grid cells.
4. Model algae and hard coral cover using environmental predictors.
5. Compare and interpret predictive relationships.
6. Use SHAP values to understand which environmental variables most influence model predictions.
7. Present reef conditions and model outputs through an interactive dashboard.

---

## Study Period

The analysis focuses on observations from:

**2010–2019**

To improve temporal consistency, reefs are retained only when they contain observations from at least **five distinct years** within the study period.

---

## Data Sources

### Reef Benthic Cover Data

The biological dataset contains reef-level benthic cover measurements, including:

- Algae cover
- Hard coral cover
- Soft coral cover
- Other benthic cover
- Reef ID
- Reef name
- Latitude and longitude
- Sampling date/year

Repeated measurements within the same reef and year are aggregated to produce annual reef-level observations.

### eReefs Environmental Data

Annual environmental data are read from eReefs NetCDF files.

The project extracts:

| Variable | Project field |
|---|---|
| Temperature | `avg_temp` |
| Salinity | `avg_salt` |
| Dissolved oxygen | `avg_oxygen` |
| Chlorophyll-a | `avg_chlorophyll` |
| Suspended solids | `avg_suspended_solids` |
| Alkalinity | `avg_alkalinity` |

Surface-level environmental observations are extracted and aggregated before being linked to the reef dataset.

> The raw reef CSV and NetCDF files are not included in this repository unless explicitly added by the project maintainers.

---

## Data Processing Pipeline

The project follows the workflow below:

```text
AIMS reef observations
        |
        v
Clean and reshape benthic-cover data
        |
        v
Filter observations to 2010–2019
        |
        v
Retain reefs with >= 5 observed years
        |
        +-------------------------+
                                  |
eReefs annual NetCDF files       |
        |                         |
        v                         |
Extract environmental variables  |
        |                         |
        v                         |
Use surface environmental layer  |
        |                         |
        +------------+------------+
                     |
                     v
        Year-specific spatial join
                     |
                     v
              reef_joined
                     |
          +----------+----------+
          |                     |
          v                     v
   Predictive models       Data exploration
          |
          v
      SHAP analysis
          |
          v
      Shiny dashboard
```

### Spatial Join

Reef locations and environmental grid points are converted to spatial objects using the `sf` package.

Both datasets are transformed to **EPSG:3857**, separated by year, and matched using the nearest environmental grid point for the corresponding year.

This produces a combined dataset containing both benthic-cover observations and environmental conditions.

---

## Predictive Modelling

### Random Forest

Separate Random Forest regression models are used for:

- **Algae cover**
- **Hard coral cover**

The models use environmental conditions as predictors.

Core predictor variables include:

```text
avg_temp
avg_salt
avg_oxygen
avg_chlorophyll
avg_suspended_solids
avg_alkalinity
```

The workflow uses a reproducible random seed:

```r
set.seed(3888)
```

and trains Random Forest models with:

```r
ntree = 500
```

Model performance is evaluated using metrics including:

- RMSE — Root Mean Squared Error
- MAE — Mean Absolute Error
- R² / pseudo-R²

The repository also contains serialized trained Random Forest objects:

```text
rf_algae.rds
rf_coral.rds
```

---

## Model Interpretation with SHAP

Random Forest predictions are interpreted using **SHAP (SHapley Additive exPlanations)**.

SHAP analysis helps identify:

- Which environmental variables contribute most strongly to predictions
- Whether a variable increases or decreases a predicted reef-cover value
- How environmental drivers differ between algae and hard coral predictions

The project uses the `fastshap` package to estimate SHAP values.

Saved SHAP outputs include:

```text
shap_matrix.rds
shap_matrix_coral.rds
```

The analysis includes:

- Mean absolute SHAP importance plots
- SHAP beeswarm-style plots
- Reef-level interpretation visualisations

---

## Interactive Dashboard

The project includes an interactive dashboard built with:

- `shiny`
- `shinydashboard`
- `leaflet`
- `plotly`
- `ggplot2`

The dashboard is designed to make the modelling results easier to explore visually.

### Dashboard Features

Depending on the version being run, the application provides functionality such as:

- Interactive GBR reef maps
- Algae-cover exploration
- Hard-coral-cover exploration
- Environmental input controls
- Reef-level model predictions
- Model interpretation plots
- SHAP-based explanations
- Interactive visualisations of environmental relationships

The dashboard allows users to examine how changing environmental conditions may affect model predictions for reef benthic composition.

---

## Repository Structure

A typical repository structure is:

```text
reef-resilience/
|
├── README.md
├── data_prep.R
├── data3888_capstone_Reef1.qmd
|
├── reef_joined.rds
├── rf_algae.rds
├── rf_coral.rds
├── shap_matrix.rds
├── shap_matrix_coral.rds
|
├── ltmp_hc_sc_a_by_site.csv          # raw reef data, if available
|
└── ncfiles_hydrodynamic/             # eReefs NetCDF files
    ├── ...2010.nc
    ├── ...2011.nc
    ├── ...
    └── ...2019.nc
```

### Key Files

| File | Description |
|---|---|
| `data_prep.R` | Data preparation, environmental extraction, spatial joining, modelling, SHAP analysis and dashboard-related code |
| `data3888_capstone_Reef1.qmd` | Main Quarto analysis containing the end-to-end project workflow |
| `reef_joined.rds` | Processed reef observations joined with environmental data |
| `rf_algae.rds` | Trained Random Forest model for algae cover |
| `rf_coral.rds` | Trained Random Forest model for hard coral cover |
| `shap_matrix.rds` | SHAP values for the algae model |
| `shap_matrix_coral.rds` | SHAP values for the hard coral model |

---

## Requirements

The analysis is written in **R**.

Major packages used throughout the project include:

```r
readr
dplyr
tidyr
tidyverse
lubridate
sf
ncdf4
raster
tidync
CFtime
randomForest
ranger
Metrics
fastshap
ggplot2
shiny
shinyjs
shinydashboard
leaflet
plotly
xgboost
lmerTest
MuMIn
broom.mixed
conflicted
```

Install packages as required, for example:

```r
install.packages(c(
  "readr",
  "dplyr",
  "tidyr",
  "tidyverse",
  "lubridate",
  "sf",
  "ncdf4",
  "raster",
  "tidync",
  "CFtime",
  "randomForest",
  "ranger",
  "Metrics",
  "fastshap",
  "ggplot2",
  "shiny",
  "shinyjs",
  "shinydashboard",
  "leaflet",
  "plotly",
  "xgboost",
  "lmerTest",
  "MuMIn",
  "broom.mixed",
  "conflicted"
))
```

> Some spatial and NetCDF packages may require system libraries depending on the operating system.

---

## Running the Project

### 1. Clone the repository

```bash
git clone <repository-url>
cd reef-resilience
```

### 2. Add the required data

Place the reef observation file in the project directory:

```text
ltmp_hc_sc_a_by_site.csv
```

Place annual eReefs NetCDF files inside:

```text
ncfiles_hydrodynamic/
```

The analysis expects environmental files covering **2010–2019**.

### 3. Run the analysis

Open either:

```text
data_prep.R
```

or:

```text
data3888_capstone_Reef1.qmd
```

in RStudio.

Run the preprocessing workflow to regenerate:

```text
reef_joined.rds
rf_algae.rds
rf_coral.rds
shap_matrix.rds
shap_matrix_coral.rds
```

### 4. Render the Quarto analysis

If Quarto is installed:

```bash
quarto render data3888_capstone_Reef1.qmd
```

Alternatively, render the document directly from RStudio.

### 5. Run the Shiny application

Run the Shiny section/application from RStudio, or place the dashboard code in an `app.R` file and run:

```r
shiny::runApp()
```

---

## Reproducibility

Random seeds are set within the modelling and SHAP workflows to make stochastic parts of the analysis more reproducible.

For example:

```r
set.seed(3888)
```

is used for model construction, while SHAP estimation uses a fixed seed before simulation.

Because the project relies on external environmental and reef datasets, exact reproduction also requires the same source files and preprocessing configuration.

---

## Outputs

Major outputs from the project include:

- Cleaned reef-year observations
- Reef/environment spatially joined dataset
- Trained algae-cover model
- Trained hard-coral-cover model
- Model evaluation statistics
- Environmental variable importance plots
- SHAP explanation plots
- Interactive reef maps
- Scenario-based reef-cover predictions

---

## Project Significance

Understanding the relationship between environmental conditions and benthic composition can help identify patterns associated with changes in coral and algae cover.

Rather than treating reef observations independently from their surrounding environment, this project integrates biological monitoring data with spatial environmental information and machine-learning methods.

The resulting workflow provides both:

1. an analytical framework for studying environmental drivers of reef composition, and
2. an interactive tool for communicating model outputs and environmental relationships.

---

## Limitations

Important limitations include:

- Coral and algae cover are modelled as separate response variables.
- Environmental observations are assigned using the nearest available eReefs grid point rather than exact reef-specific measurements.
- Annual aggregation can hide short-duration environmental disturbances.
- Predictive relationships do not necessarily imply causation.
- Reef ecology is influenced by additional biological and physical factors that may not be represented in the available predictors.
- Model performance depends on the spatial and temporal coverage of the underlying monitoring data.

---

## Future Development

Potential extensions include:

- Joint modelling of coral and algae cover
- Incorporating reef type and depth
- Adding herbivory and other biological drivers
- Including cyclone, bleaching and disturbance indicators
- Time-series modelling of individual reefs
- Improved spatial and hydrodynamic matching
- External validation on unseen reefs or future years
- Deployment of the Shiny dashboard online
- Automated data ingestion and model retraining

---

## Technologies

**Language:** R

**Data processing:** tidyverse, dplyr, tidyr

**Spatial analysis:** sf

**Environmental data:** NetCDF / ncdf4 / eReefs

**Machine learning:** Random Forest, ranger, XGBoost-related experimentation

**Model interpretation:** SHAP / fastshap

**Visualisation:** ggplot2, plotly, leaflet

**Application:** R Shiny / shinydashboard

---

## Acknowledgements

This project uses reef-monitoring and environmental datasets relating to the **Great Barrier Reef**, including long-term reef observations and **eReefs** environmental model outputs.

The project was developed as an interdisciplinary data-science investigation into the environmental factors associated with Great Barrier Reef benthic composition.

---

## License

This repository is intended for academic and research purposes.

Before redistributing source datasets, check the licensing and attribution requirements of the original data providers.
