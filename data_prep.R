#====================================================================================================
# Loading required packages
#====================================================================================================

library(readr)
library(dplyr)
library(lubridate)
library(sf)
library(tidyverse)

#====================================================================================================
# loading and manipulating reef data 
#====================================================================================================

# Read and preprocess data
reef <- read.csv("ltmp_hc_sc_a_by_site.csv") %>%
  mutate(DATE = format(as.Date(SAMPLE_DATE), "%d-%m-%Y"))

# Reshape, calculate total cover, and extract year
reef_wide <- reef %>%
  pivot_wider(
    id_cols = c(REEF_NAME, REEF_ID, LATITUDE, LONGITUDE, DATE),
    names_from = GROUP_CODE,
    values_from = COVER,
    names_glue = "{GROUP_CODE}_cover"
  ) %>%
  mutate(
    cover_total = rowSums(select(., ends_with("_cover")), na.rm = TRUE),
    year = year(dmy(DATE))
  )

# Filter dataset to years 2010 - 2020 
new_reef <- reef_wide %>%
  filter(year >= 2010, year <= 2019)

# Find REEF_IDs with at least 8 years present (because 1995-2003 = 9 years total)
reef_ids_8plus_years <- new_reef %>%
  group_by(REEF_ID) %>%
  summarise(years_present = n_distinct(year)) %>%
  filter(years_present >= 5) %>%
  pull(REEF_ID)

# Filter the reef data for those REEF_IDs
reef_total <- new_reef %>%
  filter(REEF_ID %in% reef_ids_8plus_years)


# dataset with no duplicate years 
reef_no_duplicate <- reef_total %>%
  select(-DATE) %>%  
  group_by(REEF_ID, LATITUDE, LONGITUDE, year) %>%
  summarise(
    Algae_cover = mean(Algae_cover, na.rm = TRUE),
    `Hard_Coral_cover` = mean(`Hard Coral_cover`, na.rm = TRUE),
    Other_cover = mean(Other_cover, na.rm = TRUE),
    `Soft_Coral_cover` = mean(`Soft Coral_cover`, na.rm = TRUE),
    cover_total = mean(cover_total, na.rm = TRUE),
    .groups = "drop"
  )

#====================================================================================================
# Loading required packages
#====================================================================================================

library(ncdf4)
library(raster)
library(tidync)
library(tidyr)
library(CFtime)

#====================================================================================================
# Loading in nc files
#====================================================================================================

# Set path to folder containing files
# change the directory accoringly to access your downloaded ereef data (file downloads available in the drive folder)
nc_folder <- "ncfiles_hydrodynamic"

# Load each file manually
year_2010 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2010.nc"))
year_2011 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2011.nc"))
year_2012 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2012.nc"))
year_2013 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2013.nc"))
year_2014 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2014.nc"))
year_2015 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2015.nc"))
year_2016 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2016.nc"))
year_2017 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2017.nc"))
year_2018 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2018.nc"))
year_2019 <- nc_open(file.path(nc_folder, "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-2019.nc"))

#====================================================================================================
# Define a function to extract and process one file
#====================================================================================================

process_year <- function(nc_obj, year_label) {
  # Get dimensions
  lon <- ncvar_get(nc_obj, "longitude")
  lat <- ncvar_get(nc_obj, "latitude")
  temp <- ncvar_get(nc_obj, "temp")  
  salt <- ncvar_get(nc_obj, "salt")
  suspended_solids <- ncvar_get(nc_obj, "EFI")
  chlorophyll <- ncvar_get(nc_obj, "Chl_a_sum")
  oxygen <- ncvar_get(nc_obj, "Oxygen")
  alkalinity <- ncvar_get(nc_obj, "alk")

  # Get depth index and time
  k <- 1:dim(temp)[3]
  time_raw <- ncvar_get(nc_obj, "time")
  tunits <- ncatt_get(nc_obj, "time", "units")
  cf_time <- CFtime(tunits$value, calendar = "standard", time_raw)
  timestamps <- as.Date(as_timestamp(cf_time))

  # Build dataframe and reshape
  df <- expand.grid(
    lon = lon,
    lat = lat,
    k = k,
    time = timestamps
  ) %>%
    mutate(
      temp = as.vector(temp),
      salt = as.vector(salt),
      suspended_solids = as.vector(suspended_solids),
      chlorophyll = as.vector(chlorophyll),
      oxygen = as.vector(oxygen),
      alkalinity = as.vector(alkalinity),
      year = year_label
    ) %>%
    # Filter and aggregate: keep k = 1, drop missing
    filter(!is.na(temp) & !is.na(salt) & k == 1) %>%
    group_by(time, lon, lat, year) %>%
    summarise(
      avg_temp = mean(temp, na.rm = TRUE),
      avg_salt = mean(salt, na.rm = TRUE),
      avg_suspended_solids = mean(suspended_solids, na.rm = TRUE),
      avg_chlorophyll = mean(chlorophyll, na.rm = TRUE),
      avg_oxygen = mean(oxygen, na.rm = TRUE),
      avg_alkalinity = mean(alkalinity, na.rm = TRUE),
      .groups = "drop"
    )

  return(df)
}

#====================================================================================================
# Run for all years 2010–2019
#====================================================================================================

# List of files and corresponding year labels
file_years <- 2010:2019
file_paths <- file.path(nc_folder, paste0(
  "EREEFS_AIMS-CSIRO_GBR4_H2p0_B3p1_Cq3b_Dhnd_bgc_annual-annual-", file_years, ".nc"
))

# Open and process each file
all_years_data <- lapply(seq_along(file_paths), function(i) {
  nc <- nc_open(file_paths[i])
  df <- process_year(nc, file_years[i])
  nc_close(nc)
  return(df)
})

# Combine into one data.frame
combined_df <- bind_rows(all_years_data)


#====================================================================================================
# Loading required packages
#====================================================================================================

library(sf)
library(dplyr)

#====================================================================================================
# Conduct spatial join
#====================================================================================================

# Convert reef_no_duplicate to sf while preserving original coordinates
reef_sf <- reef_no_duplicate %>%
  mutate(LATITUDE_ORIG = LATITUDE, LONGITUDE_ORIG = LONGITUDE) %>%
  st_as_sf(coords = c("LONGITUDE", "LATITUDE"), crs = 4326) %>%
  st_transform(3857)

# Convert combined_df to sf
combined_sf <- combined_df %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326) %>%
  st_transform(3857)

# Keep only overlapping years
years_in_common <- intersect(reef_sf$year, combined_sf$year)
reef_sf <- reef_sf %>% filter(year %in% years_in_common)
combined_sf <- combined_sf %>% filter(year %in% years_in_common)

# Split by year
reef_by_year <- split(reef_sf, reef_sf$year)
combined_by_year <- split(combined_sf, combined_sf$year)

# Nearest feature join per year
joined_list <- mapply(function(reef, combined) {
  idx <- st_nearest_feature(reef, combined)
  matched <- combined[idx, c("avg_temp", "avg_salt", "avg_suspended_solids", 
                              "avg_chlorophyll", "avg_oxygen", "avg_alkalinity")]
  
  result <- bind_cols(
    st_drop_geometry(reef),
    st_drop_geometry(matched)
  ) %>%
  rename(LATITUDE = LATITUDE_ORIG, LONGITUDE = LONGITUDE_ORIG)

  return(result)
}, reef_by_year, combined_by_year, SIMPLIFY = FALSE)

# Combine all years into one dataframe
reef_joined <- bind_rows(joined_list)


#====================================================================================================
# Loading required packages and data preparation
#====================================================================================================

library(lmerTest)
library(MuMIn)
library(broom.mixed)
library(dplyr)
library(Metrics)  

# Ensure year is numeric
reef_joined$year <- as.numeric(as.character(reef_joined$year))

#====================================================================================================
# LMM: algae cover
#====================================================================================================

# Fit Algae_cover model with year as fixed effect
model_algae <- lmer(Algae_cover ~ year + avg_temp + avg_salt + avg_oxygen +
                    avg_chlorophyll + avg_suspended_solids + avg_alkalinity +
                    (1 | REEF_ID), data = reef_joined)

#====================================================================================================
# LMM: hard coral cover 
#====================================================================================================

# Fit Hard Coral_cover model with year as fixed effect
model_coral <- lmer(Hard_Coral_cover ~ year + avg_temp + avg_salt + avg_oxygen +
                    avg_chlorophyll + avg_suspended_solids + avg_alkalinity +
                    (1 | REEF_ID), data = reef_joined)

#====================================================================================================
# Performance Summary
#====================================================================================================

r2_algae <- r.squaredGLMM(model_algae)
r2_coral <- r.squaredGLMM(model_coral)

cat("============= Algae Cover Model =============\n")
cat("Marginal R² (fixed effects):", round(r2_algae[1], 3), "\n")
cat("Conditional R² (fixed + random):", round(r2_algae[2], 3), "\n")

# Predictions and performance
reef_joined$pred_algae <- predict(model_algae)
rmse_algae <- rmse(reef_joined$Algae_cover, reef_joined$pred_algae)
mae_algae <- mae(reef_joined$Algae_cover, reef_joined$pred_algae)
cat("RMSE:", round(rmse_algae, 2), "\n")
cat("MAE:", round(mae_algae, 2), "\n\n")

cat("============= Hard Coral Cover Model =============\n")
cat("Marginal R²:", round(r2_coral[1], 3), "\n")
cat("Conditional R²:", round(r2_coral[2], 3), "\n")

# Predictions and performance
reef_joined$pred_coral <- predict(model_coral)
rmse_coral <- rmse(reef_joined$Hard_Coral_cover, reef_joined$pred_coral)
mae_coral <- mae(reef_joined$Hard_Coral_cover, reef_joined$pred_coral)
cat("RMSE:", round(rmse_coral, 2), "\n")
cat("MAE:", round(mae_coral, 2), "\n\n")

# Significant predictors
cat("============= Significant Predictors (p < 0.05) =============\n\n")

cat("Algae Cover:\n")
summary(model_algae)$coefficients %>%
  as.data.frame() %>%
  rownames_to_column("term") %>%
  filter(`Pr(>|t|)` < 0.05) %>%
  select(term, Estimate, `Pr(>|t|)`) %>%
  print()

cat("\nHard Coral Cover:\n")
summary(model_coral)$coefficients %>%
  as.data.frame() %>%
  rownames_to_column("term") %>%
  filter(`Pr(>|t|)` < 0.05) %>%
  select(term, Estimate, `Pr(>|t|)`) %>%
  print()


#====================================================================================================
# Loading required packages 
#====================================================================================================

library(randomForest)
library(dplyr)
library(Metrics)

# Set seed for reproducibility
set.seed(3888)

# Prepare input data — remove rows with missing values just in case
rf_data <- reef_joined %>%
  select(REEF_ID, year, avg_temp, avg_salt, avg_oxygen, avg_chlorophyll,
         avg_suspended_solids, avg_alkalinity, Algae_cover, Hard_Coral_cover) %>%
  na.omit()

#====================================================================================================
# Random Forest: Algae Cover
#====================================================================================================

rf_algae <- randomForest(
  Algae_cover ~ year + avg_temp + avg_salt + avg_oxygen +
    avg_chlorophyll + avg_suspended_solids + avg_alkalinity,
  data = rf_data,
  importance = TRUE,
  ntree = 500
)

# Predict and evaluate
rf_data$pred_algae <- predict(rf_algae, newdata = rf_data)
rmse_algae_rf <- rmse(rf_data$Algae_cover, rf_data$pred_algae)
mae_algae_rf <- mae(rf_data$Algae_cover, rf_data$pred_algae)
r2_algae_rf <- 1 - sum((rf_data$Algae_cover - rf_data$pred_algae)^2) /
                   sum((rf_data$Algae_cover - mean(rf_data$Algae_cover))^2)

#====================================================================================================
# Random Forest: Hard Coral Cover
#====================================================================================================

rf_coral <- randomForest(
  Hard_Coral_cover ~ year + avg_temp + avg_salt + avg_oxygen +
    avg_chlorophyll + avg_suspended_solids + avg_alkalinity,
  data = rf_data,
  importance = TRUE,
  ntree = 500
)

# Predict and evaluate
rf_data$pred_coral <- predict(rf_coral, newdata = rf_data)
rmse_coral_rf <- rmse(rf_data$Hard_Coral_cover, rf_data$pred_coral)
mae_coral_rf <- mae(rf_data$Hard_Coral_cover, rf_data$pred_coral)
r2_coral_rf <- 1 - sum((rf_data$Hard_Coral_cover - rf_data$pred_coral)^2) /
                    sum((rf_data$Hard_Coral_cover - mean(rf_data$Hard_Coral_cover))^2)

#====================================================================================================
# Performance Summary
#====================================================================================================

cat("============= Random Forest: Algae Cover Model =============\n")
cat("Pseudo R²:", round(r2_algae_rf, 3), "\n")
cat("RMSE:", round(rmse_algae_rf, 2), "\n")
cat("MAE :", round(mae_algae_rf, 2), "\n\n")

cat("============= Random Forest: Hard Coral Cover Model =============\n")
cat("Pseudo R²:", round(r2_coral_rf, 3), "\n")
cat("RMSE:", round(rmse_coral_rf, 2), "\n")
cat("MAE :", round(mae_coral_rf, 2), "\n")


#====================================================================================================
# SHAP values for algae RF model 
#====================================================================================================

# load librariies
library(dplyr)
library(fastshap)
library(ggplot2)
library(tidyr)

# extract model input features 
X_shap <- rf_data %>%
  select(year, avg_temp, avg_salt, avg_oxygen,
         avg_chlorophyll, avg_suspended_solids, avg_alkalinity) %>%
  data.matrix()
# safe prediction function
pred_fun <- function(model, newdata) {
  as.numeric(predict(model, newdata = as.data.frame(newdata)))
}

# computing SHAP values for all data 
set.seed(42)
shap_matrix <- fastshap::explain(
  object = rf_algae,
  X = X_shap,
  pred_wrapper = pred_fun,
  nsim = 100
)

# calculating average SHAP value per variable 
shap_avg <- as.data.frame(shap_matrix) %>%
  summarise(across(everything(), ~ mean(abs(.), na.rm = TRUE))) %>%
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Mean_SHAP")

# plotting average SHAP values 
ggplot(shap_avg, aes(x = reorder(Variable, Mean_SHAP), y = Mean_SHAP)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  theme_minimal() +
  labs(
    title = "Mean SHAP Value for Algae Cover Random Forest",
    x = "Environmental Variable",
    y = "Mean Absolute SHAP Value (Importance)"
  )

#====================================================================================================
# SHAP values for algae RF model 
#====================================================================================================
# load libraries
library(dplyr)
library(fastshap)
library(ggplot2)
library(tidyr)

# extract model input features
X_shap_coral <- rf_data %>%
  select(year, avg_temp, avg_salt, avg_oxygen,
         avg_chlorophyll, avg_suspended_solids, avg_alkalinity) %>%
  data.matrix()

# safe prediction function
pred_fun_coral <- function(model, newdata) {
  as.numeric(predict(model, newdata = as.data.frame(newdata)))
}

# computing SHAP values for all data
set.seed(42)
shap_matrix_coral <- fastshap::explain(
  object = rf_coral,
  X = X_shap_coral,
  pred_wrapper = pred_fun_coral,
  nsim = 100
)

# calculating average SHAP value per variable
shap_avg_coral <- as.data.frame(shap_matrix_coral) %>%
  summarise(across(everything(), ~ mean(abs(.), na.rm = TRUE))) %>%
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Mean_SHAP")

# plotting average SHAP values
ggplot(shap_avg_coral, aes(x = reorder(Variable, Mean_SHAP), y = Mean_SHAP)) +
  geom_col(fill = "darkorange") +
  coord_flip() +
  theme_minimal() +
  labs(
    title = "Mean SHAP Value for Hard Coral Cover Random Forest",
    x = "Environmental Variable",
    y = "Mean Absolute SHAP Value (Importance)"
  )

#====================================================================================================
# SHAP beeswarm plot for Hard Coral Cover RF model
#====================================================================================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(fastshap)

# Convert SHAP matrix to long format
shap_long_coral <- as.data.frame(shap_matrix_coral) %>%
  mutate(row_id = row_number()) %>%
  pivot_longer(-row_id, names_to = "Variable", values_to = "SHAP")

# Bind feature values and standardize within each variable
X_df_coral <- as.data.frame(X_shap_coral) %>%
  mutate(row_id = row_number()) %>%
  pivot_longer(-row_id, names_to = "Variable", values_to = "Feature_Value") %>%
  group_by(Variable) %>%
  mutate(Feature_Value_Standardized = scale(Feature_Value)[,1]) %>%
  ungroup()

# Merge SHAP and standardized feature values
shap_beeswarm <- left_join(shap_long_coral, X_df_coral, by = c("row_id", "Variable"))

# Plot with standardized color scale
ggplot(shap_beeswarm, aes(
  x = SHAP,
  y = reorder(Variable, SHAP, FUN = function(x) mean(abs(x))),
  color = Feature_Value_Standardized
)) +
  geom_jitter(height = 0.2, alpha = 0.6, size = 1.2) +
  scale_color_viridis_c(option = "D") +
  theme_minimal() +
  labs(
    title = "SHAP Beeswarm Plot – Hard Coral Cover RF Model",
    x = "SHAP Value (Impact on Model Output)",
    y = "Environmental Variable",
    color = "Feature Value"
  )


#====================================================================================================
# Visualisation of model performances for LMM
# possibly put this onto a map to visualise 
#====================================================================================================
# Load required packages
library(dplyr)
library(Metrics)
library(ggplot2)

# Calculate RMSE and MAE per reef
reef_metrics <- reef_joined %>%
  group_by(REEF_ID) %>%
  summarise(
    RMSE = rmse(Algae_cover, pred_algae),
    MAE  = mae(Algae_cover, pred_algae)
  )

# Plot RMSE per REEF_ID
ggplot(reef_metrics, aes(x = REEF_ID, y = RMSE)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(title = "RMSE by REEF_ID", x = "REEF_ID", y = "RMSE") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot MAE per REEF_ID
ggplot(reef_metrics, aes(x = REEF_ID, y = MAE)) +
  geom_bar(stat = "identity", fill = "darkorange") +
  labs(title = "MAE by REEF_ID", x = "REEF_ID", y = "MAE") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


library(shiny)
library(shinyjs)
library(leaflet)
library(shinydashboard)
library(xgboost)
library(tidyverse)
library(plotly)

# Define UI for the application
ui <- dashboardPage(
  dashboardHeader(title = "Reef Cover Predictions"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Opening", tabName = "opening", icon = icon("home")),
      menuItem("Exploration", tabName = "exploration", icon = icon("globe")),
      menuItem("Interpretation", tabName = "interpretation", icon = icon("chart-line"))
    )
  ),
  dashboardBody(
    tabItems(
      # Opening Tab
      tabItem(tabName = "opening",
              fluidRow(
                box(title = "Welcome to the Reef Cover Prediction App",
                    width = 12, status = "primary", solidHeader = TRUE,
                    p("This app uses environmental data to predict algae and coral cover in the Great Barrier Reef.")
                )
              )
      ),
      
      # Exploration Tab (Interactive Map and Sliders)
      tabItem(tabName = "exploration",
              fluidRow(
                tabBox(
                  title = "Cover Prediction", width = 12,
                  tabPanel("Algae Cover", 
                           leafletOutput("map_algae", height = 600),
                           sliderInput("temp", "Temperature (°C):", min = 0, max = 50, value = 25),
                           sliderInput("salt", "Salinity:", min = 0, max = 50, value = 25),
                           sliderInput("suspended", "Suspended Solids (EFI):", min = 0, max = 100, value = 50),
                           sliderInput("oxygen", "Oxygen:", min = 0, max = 25, value = 10),
                           sliderInput("alkalinity", "Alkalinity:", min = 0, max = 2000, value = 1000)
                  ),
                  tabPanel("Hard Coral Cover", 
                           leafletOutput("map_coral", height = 600),
                           sliderInput("temp_coral", "Temperature (°C):", min = 0, max = 50, value = 25),
                           sliderInput("salt_coral", "Salinity:", min = 0, max = 50, value = 25),
                           sliderInput("suspended_coral", "Suspended Solids (EFI):", min = 0, max = 100, value = 50),
                           sliderInput("oxygen_coral", "Oxygen:", min = 0, max = 25, value = 10),
                           sliderInput("alkalinity_coral", "Alkalinity:", min = 0, max = 2000, value = 1000)
                  )
                )
              )
      ),
      
      # Interpretation Tab
      tabItem(tabName = "interpretation",
              fluidRow(
                box(title = "Model Interpretation", width = 12,
                    plotlyOutput("model_interpretation")
                )
              )
      )
    )
  )
)

# Define the predict_cover function with correct column names
predict_cover <- function(model, temp, salt, suspended, oxygen, alkalinity) {
  # Ensure the input is a data frame
  data <- data.frame(
    avg_temp = temp,
    avg_salt = salt,
    Suspended_solids = suspended,  # Correct column names
    Oxygen = oxygen,                # Correct column names
    Alkalinity = alkalinity         # Correct column names
  )
  
  # Make prediction using the model
  pred <- predict(model, as.matrix(data))
  
  # Ensure the prediction is returned as a data frame
  pred_df <- data.frame(pred = pred)
  return(pred_df)
}

# Server logic
server <- function(input, output, session) {
  
  # Reactive expression for predicting algae cover
  prediction_data_algae <- reactive({
    # Get user input for environmental conditions
    temp <- input$temp
    salt <- input$salt
    suspended <- input$suspended
    oxygen <- input$oxygen
    alkalinity <- input$alkalinity
    
    # Predict algae cover using the model
    cover <- predict_cover(model_algae, temp, salt, suspended, oxygen, alkalinity)
    
    # Return predictions along with the original data
    reef_data <- reef_joined_clean
    reef_data$algae_cover <- cover$pred  # Use the correct column name from the prediction
    return(reef_data)
  })
  
  # Generate the Leaflet map for Algae Cover
  output$map_algae <- renderLeaflet({
    reef_coords <- as.data.frame(prediction_data_algae()) %>%  # Ensure it's a data frame
      select(LATITUDE, LONGITUDE, algae_cover)  # Now you can safely use select
    
    # Custom color scale for algae cover
    color_scale <- colorBin(palette = "YlOrRd", 
                            domain = reef_coords$algae_cover, 
                            bins = c(0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100))
    
    leaflet(reef_coords) %>%
      addTiles() %>%
      addCircleMarkers(
        lng = ~LONGITUDE, lat = ~LATITUDE, 
        color = ~color_scale(algae_cover),
        radius = 5, opacity = 0.7,
        popup = ~paste("Algae Cover:", round(algae_cover, 2))
      ) %>%
      addLegend(
        position = "bottomright",
        pal = color_scale,
        values = ~algae_cover,
        title = "Algae Cover",
        labFormat = labelFormat(suffix = "%")
      )
  })
  
  # Reactive expression for predicting coral cover
  prediction_data_coral <- reactive({
    # Get user input for environmental conditions
    temp_coral <- input$temp_coral
    salt_coral <- input$salt_coral
    suspended_coral <- input$suspended_coral
    oxygen_coral <- input$oxygen_coral
    alkalinity_coral <- input$alkalinity_coral
    
    # Predict coral cover using the model
    cover <- predict_cover(model_coral, temp_coral, salt_coral, suspended_coral, oxygen_coral, alkalinity_coral)
    
    # Return predictions along with the original data
    reef_data <- reef_joined_clean
    reef_data$coral_cover <- cover$pred  # Use the correct column name from the prediction
    return(reef_data)
  })
  
  # Generate the Leaflet map for Hard Coral Cover
  output$map_coral <- renderLeaflet({
    reef_coords <- as.data.frame(prediction_data_coral()) %>%  # Ensure it's a data frame
      select(LATITUDE, LONGITUDE, coral_cover)  # Now you can safely use select
    
    # Custom color scale for coral cover
    color_scale_coral <- colorBin(palette = "YlOrRd", 
                                  domain = reef_coords$coral_cover, 
                                  bins = c(0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100))
    
    leaflet(reef_coords) %>%
      addTiles() %>%
      addCircleMarkers(
        lng = ~LONGITUDE, lat = ~LATITUDE, 
        color = ~color_scale_coral(coral_cover),
        radius = 5, opacity = 0.7,
        popup = ~paste("Hard Coral Cover:", round(coral_cover, 2))
      ) %>%
      addLegend(
        position = "bottomright",
        pal = color_scale_coral,
        values = ~coral_cover,
        title = "Hard Coral Cover",
        labFormat = labelFormat(suffix = "%")
      )
  })
  
}

# Run the application
shinyApp(ui = ui, server = server)

#===============================
# Predict Algae Cover with Custom Inputs
#===============================

# Define custom environmental inputs
custom_input <- data.frame(
  year = 2012,
  avg_temp = 27.5,
  avg_salt = 35.2,
  avg_oxygen = 6.8,
  avg_chlorophyll = 0.45,
  avg_suspended_solids = 12.3,
  avg_alkalinity = 2.4
)

# Predict algae cover using trained RF model
predicted_algae_cover <- predict(rf_algae, newdata = custom_input)

# Output the result
cat("Predicted Algae Cover:", round(predicted_algae_cover, 2), "\n")

saveRDS(reef_joined, "reef_joined.rds")
saveRDS(rf_algae,     "rf_algae.rds")
saveRDS(rf_coral,     "rf_coral.rds")
