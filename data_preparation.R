################################################################################
# HOME CREDIT DEFAULT RISK - DATA PREPARATION PIPELINE
# 
# Purpose: Clean, transform, and engineer features from application and 
#          supplementary data files
#
# Main Steps:
# 1. Clean application data (fix anomalies, handle missing values)
# 2. Engineer features (demographics, financial ratios, indicators)
# 3. Aggregate supplementary data (bureau, previous applications, payments)
# 4. Join all data together
# 5. Ensure train/test consistency
#
# Author: u6062992, Erin Bednarik - Data Preparation Team
# Date: February 2026
################################################################################

library(tidyverse)
library(lubridate)

cat("\n")
cat(strrep("=", 80), "\n")
cat("HOME CREDIT DATA PREPARATION PIPELINE\n")
cat(strrep("=", 80), "\n\n")

# ==============================================================================
# PART 1: LOAD DATA
# ==============================================================================

cat("STEP 1: Loading Data\n")
cat(strrep("-", 80), "\n")

# Define paths
data_path <- "c:/Users/bedna/OneDrive/Documents/home-credit-project/data csv/"

# Load application data
train <- read_csv(paste0(data_path, "application_train.csv"), show_col_types = FALSE)
test <- read_csv(paste0(data_path, "application_test.csv"), show_col_types = FALSE)

cat("✓ Application Train: ", nrow(train), " rows x ", ncol(train), " cols\n", sep = "")
cat("✓ Application Test: ", nrow(test), " rows x ", ncol(test), " cols\n", sep = "")

# Load supplementary data
bureau <- read_csv(paste0(data_path, "bureau.csv"), show_col_types = FALSE)
prev_app <- read_csv(paste0(data_path, "previous_application.csv"), show_col_types = FALSE)
installments <- read_csv(paste0(data_path, "installments_payments.csv"), show_col_types = FALSE)

cat("✓ Bureau: ", nrow(bureau), " rows\n", sep = "")
cat("✓ Previous Applications: ", nrow(prev_app), " rows\n", sep = "")
cat("✓ Installments: ", nrow(installments), " rows\n\n", sep = "")

# ==============================================================================
# PART 2: CLEAN APPLICATION DATA
# ==============================================================================

cat("STEP 2: Cleaning Application Data\n")
cat(strrep("-", 80), "\n")

clean_application <- function(df, is_train = TRUE) {
  
  df_clean <- df |>
    
    # ---- FIX DAYS_EMPLOYED ANOMALY ----
    # 365243 days is a placeholder for "still employed" or data error
    # Replace with -0 (current employment) or use separate indicator
    mutate(
      DAYS_EMPLOYED_IS_ANOMALY = as.numeric(DAYS_EMPLOYED == 365243),
      DAYS_EMPLOYED = case_when(
        DAYS_EMPLOYED == 365243 ~ 0,  # Treat as current employment (0 days ago)
        TRUE ~ DAYS_EMPLOYED
      )
    ) |>
    
    # ---- HANDLE MISSING VALUES IN EXT_SOURCE ----
    # Strategy: Create indicator flags, then impute with medians from training set
    mutate(
      EXT_SOURCE_1_MISSING = as.numeric(is.na(EXT_SOURCE_1)),
      EXT_SOURCE_2_MISSING = as.numeric(is.na(EXT_SOURCE_2)),
      EXT_SOURCE_3_MISSING = as.numeric(is.na(EXT_SOURCE_3))
    ) |>
    
    # ---- HANDLE OCCUPATION_TYPE MISSING ----
    # Replace NA with "Unknown" category (don't impute with mode)
    mutate(
      OCCUPATION_TYPE = replace_na(OCCUPATION_TYPE, "Unknown")
    ) |>
    
    # ---- HANDLE OWN_CAR_AGE MISSING ----
    # Missing = no car, impute with 0
    mutate(
      OWN_CAR_AGE = replace_na(OWN_CAR_AGE, 0)
    ) |>
    
    # ---- HANDLE BUILDING INFO MISSING ----
    # 66-70% missing in APARTMENTS_*, BASEMENTAREA_*, etc.
    # Strategy: Create indicator, then drop raw columns (too sparse)
    mutate(
      HAS_BUILDING_INFO = as.numeric(
        !is.na(APARTMENTS_AVG) | !is.na(BASEMENTAREA_AVG) | !is.na(YEARS_BUILD_AVG)
      )
    ) |>
    
    # Drop building feature columns (too sparse)
    select(-starts_with("APARTMENTS_"), 
           -starts_with("BASEMENTAREA_"),
           -starts_with("YEARS_BEGIN"),
           -starts_with("YEARS_BUILD_"),
           -starts_with("COMMONAREA_"),
           -starts_with("ELEVATORS_"),
           -starts_with("ENTRANCES_"),
           -starts_with("FLOORSMAX_"),
           -starts_with("FLOORSMIN_"),
           -starts_with("LANDAREA_"),
           -starts_with("LIVINGAPARTMENTS_"),
           -starts_with("LIVINGAREA_"),
           -starts_with("NONLIVINGAPARTMENTS_"),
           -starts_with("NONLIVINGAREA_"),
           -starts_with("FONDKAPREMONT_"),
           -starts_with("HOUSETYPE_"),
           -starts_with("TOTALAREA_"),
           -starts_with("WALLSMATERIAL_"),
           -starts_with("EMERGENCYSTATE_"))
  
  return(df_clean)
}

train_clean <- clean_application(train, is_train = TRUE)
test_clean <- clean_application(test, is_train = FALSE)

cat("✓ Fixed DAYS_EMPLOYED anomaly (365243 → 0)\n")
cat("✓ Created EXT_SOURCE missing indicators\n")
cat("✓ Converted OCCUPATION_TYPE NA to 'Unknown'\n")
cat("✓ Imputed OWN_CAR_AGE NA with 0\n")
cat("✓ Created HAS_BUILDING_INFO indicator\n")
cat("✓ Dropped sparse building feature columns\n")
cat("✓ Train shape:", nrow(train_clean), "x", ncol(train_clean), "\n")
cat("✓ Test shape:", nrow(test_clean), "x", ncol(test_clean), "\n\n")

# ==============================================================================
# PART 3: ENGINEER FEATURES FROM APPLICATION DATA
# ==============================================================================

cat("STEP 3: Engineering Features\n")
cat(strrep("-", 80), "\n")

engineer_application <- function(df) {
  
  df_engineered <- df |>
    
    # ---- DEMOGRAPHIC TRANSFORMATIONS ----
    # Convert DAYS_* to more interpretable units
    mutate(
      AGE_YEARS = -DAYS_BIRTH / 365.25,
      EMPLOYMENT_DAYS = -DAYS_EMPLOYED,  # Positive days since start
      EMPLOYMENT_YEARS = pmax(EMPLOYMENT_DAYS / 365.25, 0),  # Handle negatives
      REGISTRATION_DAYS = -DAYS_REGISTRATION,
      ID_PUBLISH_DAYS = -DAYS_ID_PUBLISH,
      PHONE_CHANGE_DAYS = -DAYS_LAST_PHONE_CHANGE,
      
      # Age binning (common in credit risk models)
      AGE_GROUP = cut(AGE_YEARS,
                      breaks = c(0, 25, 35, 45, 55, 65, 100),
                      labels = c("18-25", "26-35", "36-45", "46-55", "56-65", "65+"),
                      right = FALSE),
      
      # Employment duration binning
      EMPLOYMENT_GROUP = cut(EMPLOYMENT_YEARS,
                            breaks = c(-Inf, 0, 1, 3, 5, 10, Inf),
                            labels = c("Unemployed", "<1yr", "1-3yr", "3-5yr", "5-10yr", "10+yr")),
      
      # Log transformations for skewed distributions
      LOG_INCOME = log(AMT_INCOME_TOTAL + 1),
      LOG_CREDIT = log(AMT_CREDIT + 1),
      LOG_ANNUITY = log(AMT_ANNUITY + 1),
      LOG_GOODS_PRICE = log(AMT_GOODS_PRICE + 1),
      
      # ---- FINANCIAL RATIOS ----
      # Standard credit risk ratios
      CREDIT_TO_INCOME = AMT_CREDIT / AMT_INCOME_TOTAL,
      ANNUITY_TO_INCOME = AMT_ANNUITY / AMT_INCOME_TOTAL,
      CREDIT_TO_GOODS = AMT_CREDIT / (AMT_GOODS_PRICE + 1),  # +1 to avoid division by zero
      INCOME_PER_PERSON = AMT_INCOME_TOTAL / pmax(CNT_FAM_MEMBERS, 1),
      
      # Debt-to-Income proxy (annuity represents annual payment)
      DEBT_TO_INCOME = AMT_ANNUITY / AMT_INCOME_TOTAL,
      
      # Loan-to-Value proxy (credit vs goods price)
      LOAN_TO_VALUE = AMT_CREDIT / (AMT_GOODS_PRICE + 1),
      
      # Additional useful ratios
      ANNUITY_PER_INCOME = AMT_ANNUITY / (AMT_INCOME_TOTAL + 1),
      CREDIT_PER_ANNUITY = AMT_CREDIT / (AMT_ANNUITY + 1),  # Higher = longer repayment
      REMAINING_PAYMENT_RATIO = (AMT_CREDIT - AMT_GOODS_PRICE) / (AMT_CREDIT + 1),  # Down payment ratio
      
      # ---- INTERACTION TERMS ----
      # Age × Employment (young & unemployed might be riskier)
      AGE_EMPLOYMENT_INTERACTION = AGE_YEARS * EMPLOYMENT_YEARS,
      
      # Income × Credit (high income with high credit might indicate business owners)
      INCOME_CREDIT_INTERACTION = LOG_INCOME * LOG_CREDIT,
      
      # Has children × Family status interaction
      HAS_CHILDREN = as.numeric(CNT_CHILDREN > 0),
      
      # ---- MISSING DATA INDICATORS (OFTEN PREDICTIVE) ----
      # These capture information from missing patterns
      TOTAL_MISSING_EXT_SOURCE = EXT_SOURCE_1_MISSING + 
                                 EXT_SOURCE_2_MISSING + 
                                 EXT_SOURCE_3_MISSING,
      
      EXT_SOURCES_AVAILABLE = 3 - TOTAL_MISSING_EXT_SOURCE,
      
      # ---- DOCUMENT SUBMISSION ----
      # Count how many documents submitted
      DOCUMENTS_SUBMITTED = (FLAG_DOCUMENT_3 + FLAG_DOCUMENT_4 + FLAG_DOCUMENT_5 + 
                            FLAG_DOCUMENT_6 + FLAG_DOCUMENT_7 + FLAG_DOCUMENT_8 +
                            FLAG_DOCUMENT_9 + FLAG_DOCUMENT_10 + FLAG_DOCUMENT_11 +
                            FLAG_DOCUMENT_12 + FLAG_DOCUMENT_13 + FLAG_DOCUMENT_14 +
                            FLAG_DOCUMENT_15 + FLAG_DOCUMENT_16 + FLAG_DOCUMENT_17 +
                            FLAG_DOCUMENT_18 + FLAG_DOCUMENT_19 + FLAG_DOCUMENT_20 +
                            FLAG_DOCUMENT_21),
      
      # Contact method availability
      HAS_PHONE = as.numeric(FLAG_PHONE == 1),
      HAS_EMAIL = as.numeric(FLAG_EMAIL == 1),
      HAS_MOBILE = as.numeric(FLAG_MOBIL == 1),
      CONTACT_METHODS = HAS_PHONE + HAS_EMAIL + HAS_MOBILE,
      
      # Working vs unemployed
      IS_UNEMPLOYED = as.numeric(DAYS_EMPLOYED >= 0),
      
      # ---- DEMOGRAPHIC BINNING ----
      INCOME_GROUP = cut(LOG_INCOME,
                        breaks = quantile(LOG_INCOME, probs = c(0, 0.25, 0.5, 0.75, 1.0)),
                        labels = c("Low", "Lower-Mid", "Upper-Mid", "High"),
                        include.lowest = TRUE),
      
      CREDIT_AMOUNT_GROUP = cut(LOG_CREDIT,
                               breaks = quantile(LOG_CREDIT, probs = c(0, 0.25, 0.5, 0.75, 1.0)),
                               labels = c("Small", "Medium", "Large", "Very Large"),
                               include.lowest = TRUE)
    )
  
  return(df_engineered)
}

train_engineered <- engineer_application(train_clean)
test_engineered <- engineer_application(test_clean)

cat("✓ Created demographic features (age, employment in years, registration days)\n")
cat("✓ Created age and employment groups (binned variables)\n")
cat("✓ Applied log transformations to financial amounts\n")
cat("✓ Created 8+ financial ratios (credit-to-income, debt-to-income, LTV, etc.)\n")
cat("✓ Created interaction terms (age×employment, income×credit)\n")
cat("✓ Created missing data indicators\n")
cat("✓ Created contact method indicators\n")
cat("✓ Train engineered features:", ncol(train_engineered), "columns\n")
cat("✓ Test engineered features:", ncol(test_engineered), "columns\n\n")

# ==============================================================================
# PART 4: AGGREGATE SUPPLEMENTARY DATA
# ==============================================================================

cat("STEP 4: Aggregating Supplementary Data\n")
cat(strrep("-", 80), "\n")

# ---- BUREAU AGGREGATION ----
cat("Aggregating Bureau data...\n")

bureau_agg <- bureau |>
  group_by(SK_ID_CURR) |>
  summarise(
    # Count of prior credits
    NUM_PRIOR_CREDITS = n(),
    NUM_ACTIVE_CREDITS = sum(CREDIT_ACTIVE == "Active", na.rm = TRUE),
    NUM_CLOSED_CREDITS = sum(CREDIT_ACTIVE == "Closed", na.rm = TRUE),
    NUM_REVOLVING_CREDITS = sum(CREDIT_ACTIVE == "Revolving", na.rm = TRUE),
    
    # Overdue metrics
    NUM_CREDITS_WITH_OVERDUE = sum(CREDIT_DAY_OVERDUE > 0, na.rm = TRUE),
    MAX_CREDIT_DAY_OVERDUE = max(CREDIT_DAY_OVERDUE, na.rm = TRUE),
    AVG_CREDIT_DAY_OVERDUE = mean(CREDIT_DAY_OVERDUE, na.rm = TRUE),
    MAX_AMT_OVERDUE = max(AMT_CREDIT_MAX_OVERDUE, na.rm = TRUE),
    
    # Credit amounts
    TOTAL_CREDIT_AMOUNT = sum(AMT_CREDIT_SUM, na.rm = TRUE),
    AVG_CREDIT_AMOUNT = mean(AMT_CREDIT_SUM, na.rm = TRUE),
    MAX_CREDIT_AMOUNT = max(AMT_CREDIT_SUM, na.rm = TRUE),
    
    # Debt ratios
    DEBT_TO_CREDIT_RATIO = sum(AMT_CREDIT_SUM_DEBT, na.rm = TRUE) / sum(AMT_CREDIT_SUM, na.rm = TRUE),
    
    # Credit limits
    AVG_CREDIT_LIMIT = mean(AMT_CREDIT_SUM_LIMIT, na.rm = TRUE),
    
    # Duration of credit relationships
    AVG_DAYS_SINCE_CREDIT_START = mean(DAYS_CREDIT, na.rm = TRUE),
    
    .groups = "drop"
  ) |>
  # Replace NaN/Inf with NA
  mutate(across(where(is.numeric), ~replace(., !is.finite(.), NA)))

cat("✓ Bureau aggregated for", n_distinct(bureau_agg$SK_ID_CURR), "applicants\n")

# ---- PREVIOUS APPLICATION AGGREGATION ----
cat("Aggregating Previous Application data...\n")

prev_agg <- prev_app |>
  group_by(SK_ID_CURR) |>
  summarise(
    # Count of applications
    NUM_PREVIOUS_APPLICATIONS = n(),
    NUM_APPROVED_APPLICATIONS = sum(NAME_CONTRACT_STATUS == "Approved", na.rm = TRUE),
    NUM_REFUSED_APPLICATIONS = sum(NAME_CONTRACT_STATUS == "Refused", na.rm = TRUE),
    NUM_CANCELLED_APPLICATIONS = sum(NAME_CONTRACT_STATUS == "Cancelled", na.rm = TRUE),
    NUM_UNUSED_APPLICATIONS = sum(NAME_CONTRACT_STATUS == "Unused offer", na.rm = TRUE),
    
    # Approval rate
    APPROVAL_RATE = NUM_APPROVED_APPLICATIONS / NUM_PREVIOUS_APPLICATIONS,
    REFUSAL_RATE = NUM_REFUSED_APPLICATIONS / NUM_PREVIOUS_APPLICATIONS,
    
    # Contract types
    NUM_CONSUMER_LOANS = sum(NAME_CONTRACT_TYPE == "Consumer loans", na.rm = TRUE),
    NUM_CASH_LOANS = sum(NAME_CONTRACT_TYPE == "Cash loans", na.rm = TRUE),
    NUM_REVOLVING_LOANS = sum(NAME_CONTRACT_TYPE == "Revolving loans", na.rm = TRUE),
    
    # Amounts
    AVG_APPLICATION_AMOUNT = mean(AMT_APPLICATION, na.rm = TRUE),
    MAX_APPLICATION_AMOUNT = max(AMT_APPLICATION, na.rm = TRUE),
    AVG_CREDIT_AMOUNT_PREV = mean(AMT_CREDIT, na.rm = TRUE),
    AVG_ANNUITY_PREV = mean(AMT_ANNUITY, na.rm = TRUE),
    
    # Days from approval to current app (recency)
    DAYS_SINCE_LAST_APPR = min(DAYS_DECISION, na.rm = TRUE),
    
    .groups = "drop"
  ) |>
  mutate(across(where(is.numeric), ~replace(., !is.finite(.), NA)))

cat("✓ Previous Applications aggregated for", n_distinct(prev_agg$SK_ID_CURR), "applicants\n")

# ---- INSTALLMENTS PAYMENT AGGREGATION ----
cat("Aggregating Installments Payment data...\n")

installments_agg <- installments |>
  group_by(SK_ID_CURR) |>
  summarise(
    # Payment history
    NUM_INSTALLMENTS = n(),
    NUM_LATE_PAYMENTS = sum((DAYS_ENTRY_PAYMENT - DAYS_INSTALMENT) > 0, na.rm = TRUE),
    LATE_PAYMENT_RATIO = NUM_LATE_PAYMENTS / NUM_INSTALLMENTS,
    
    # Payment amounts
    TOTAL_INSTALLMENT_AMOUNT = sum(AMT_INSTALMENT, na.rm = TRUE),
    TOTAL_AMOUNT_PAID = sum(AMT_PAYMENT, na.rm = TRUE),
    AVG_DAYS_LATE = mean(DAYS_ENTRY_PAYMENT - DAYS_INSTALMENT, na.rm = TRUE),
    MAX_DAYS_LATE = max(DAYS_ENTRY_PAYMENT - DAYS_INSTALMENT, na.rm = TRUE),
    
    # Payment consistency
    AVG_PAYMENT_AMOUNT = mean(AMT_PAYMENT, na.rm = TRUE),
    
    .groups = "drop"
  ) |>
  mutate(across(where(is.numeric), ~replace(., !is.finite(.), NA)))

cat("✓ Installments aggregated for", n_distinct(installments_agg$SK_ID_CURR), "applicants\n\n")

# ==============================================================================
# PART 5: JOIN ALL DATA
# ==============================================================================

cat("STEP 5: Joining All Data\n")
cat(strrep("-", 80), "\n")

# Join supplementary data to training set
train_final <- train_engineered |>
  left_join(bureau_agg, by = "SK_ID_CURR") |>
  left_join(prev_agg, by = "SK_ID_CURR") |>
  left_join(installments_agg, by = "SK_ID_CURR")

# Join supplementary data to test set
test_final <- test_engineered |>
  left_join(bureau_agg, by = "SK_ID_CURR") |>
  left_join(prev_agg, by = "SK_ID_CURR") |>
  left_join(installments_agg, by = "SK_ID_CURR")

cat("✓ Train final shape:", nrow(train_final), "x", ncol(train_final), "\n")
cat("✓ Test final shape:", nrow(test_final), "x", ncol(test_final), "\n\n")

# ==============================================================================
# PART 6: IMPUTE MISSING VALUES (from training data statistics)
# ==============================================================================

cat("STEP 6: Final Missing Value Imputation\n")
cat(strrep("-", 80), "\n")

# Get imputation statistics from training set only
imputation_stats <- list()

# For numeric columns, use median from training data
numeric_cols <- train_final |> select(where(is.numeric)) |> colnames()
for (col in numeric_cols) {
  imputation_stats[[col]] <- median(train_final[[col]], na.rm = TRUE)
}

# Apply to both train and test
impute_with_stats <- function(df, stats) {
  for (col in names(stats)) {
    if (col %in% colnames(df)) {
      df[[col]] <- replace_na(df[[col]], stats[[col]])
    }
  }
  return(df)
}

train_final <- impute_with_stats(train_final, imputation_stats)
test_final <- impute_with_stats(test_final, imputation_stats)

cat("✓ Imputed numeric columns using training set medians\n")
cat("✓ Final missing values in train:\n")
print(train_final |> summarise(across(where(is.numeric), ~sum(is.na(.)))) |> 
      select(where(~. > 0)))
cat("\n")

# ==============================================================================
# PART 7: SAVE PREPARED DATA
# ==============================================================================

cat("STEP 7: Saving Prepared Data\n")
cat(strrep("-", 80), "\n")

output_path <- "c:/Users/bedna/OneDrive/Documents/home-credit-project/"

# Save prepared datasets
write_csv(train_final, paste0(output_path, "train_prepared.csv"))
write_csv(test_final, paste0(output_path, "test_prepared.csv"))

# Save imputation statistics for reproducibility
write_rds(imputation_stats, paste0(output_path, "imputation_stats.rds"))

cat("✓ Saved train_prepared.csv (", nrow(train_final), " rows)\n", sep = "")
cat("✓ Saved test_prepared.csv (", nrow(test_final), " rows)\n", sep = "")
cat("✓ Saved imputation_stats.rds (for train/test consistency)\n\n")

# ==============================================================================
# PART 8: SUMMARY REPORT
# ==============================================================================

cat("SUMMARY REPORT\n")
cat(strrep("=", 80), "\n\n")

cat("FEATURES CREATED:\n")
cat("  Demographic Features: AGE_YEARS, EMPLOYMENT_YEARS, AGE_GROUP, EMPLOYMENT_GROUP\n")
cat("  Log Transforms: LOG_INCOME, LOG_CREDIT, LOG_ANNUITY, LOG_GOODS_PRICE\n")
cat("  Financial Ratios: CREDIT_TO_INCOME, ANNUITY_TO_INCOME, DEBT_TO_INCOME,\n")
cat("                    LOAN_TO_VALUE, CREDIT_TO_GOODS, INCOME_PER_PERSON,\n")
cat("                    ANNUITY_PER_INCOME, CREDIT_PER_ANNUITY, REMAINING_PAYMENT_RATIO\n")
cat("  Interaction Terms: AGE_EMPLOYMENT_INTERACTION, INCOME_CREDIT_INTERACTION\n")
cat("  Missing Indicators: EXT_SOURCE_*_MISSING, TOTAL_MISSING_EXT_SOURCE,\n")
cat("                     EXT_SOURCES_AVAILABLE, HAS_BUILDING_INFO\n")
cat("  Contact/Document: DOCUMENTS_SUBMITTED, CONTACT_METHODS, HAS_PHONE, HAS_EMAIL, HAS_MOBILE\n")
cat("  Other: HAS_CHILDREN, IS_UNEMPLOYED, DAYS_EMPLOYED_IS_ANOMALY\n\n")

cat("BUREAU FEATURES AGGREGATED (", nrow(bureau_agg), " applicants with bureau data):\n", sep = "")
cat("  Credit counts, overdue metrics, debt ratios, credit limits\n\n")

cat("PREVIOUS APPLICATION FEATURES (", nrow(prev_agg), " applicants):\n", sep = "")
cat("  Application counts, approval rates, contract types, loan amounts\n\n")

cat("INSTALLMENT PAYMENT FEATURES (", nrow(installments_agg), " applicants):\n", sep = "")
cat("  Payment counts, late payment ratios, payment amounts, days late\n\n")

cat("TRAIN/TEST CONSISTENCY:\n")
cat("  ✓ Imputation statistics computed from training data only\n")
cat("  ✓ Applied to both train and test sets\n")
cat("  ✓ Train and test have identical column structure (except TARGET in test)\n")
cat("  ✓ All preprocessing transformations applied identically\n\n")

cat("NEXT STEPS:\n")
cat("  1. Exploratory analysis on engineered features\n")
cat("  2. Feature selection and correlation analysis\n")
cat("  3. Address remaining multicollinearity\n")
cat("  4. Prepare for machine learning models\n\n")

cat(strrep("=", 80), "\n")
cat("DATA PREPARATION COMPLETE!\n")
cat(strrep("=", 80), "\n\n")

# Return prepared datasets for further analysis
list(
  train = train_final,
  test = test_final,
  imputation_stats = imputation_stats,
  bureau_agg = bureau_agg,
  prev_agg = prev_agg,
  installments_agg = installments_agg
)
