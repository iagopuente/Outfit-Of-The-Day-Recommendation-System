# Load necessary libraries
library(RSQLite)  # For SQLite database operations
library(dplyr)    # For data manipulation

# Step 1: Read raw data from products_raw.csv
cat("Reading raw data from 'products_raw.csv'...\n")  # Log message to indicate data reading process
products_raw <- read.csv("products_raw.csv", stringsAsFactors = FALSE)  # Load raw product data into a data frame

# Step 2: Inspect column names for debugging
cat("Column names in the dataset:\n")  # Log message to display column names
print(colnames(products_raw))  # Print column names to verify the structure of the dataset

# Step 3: Data cleaning
cat("Cleaning data...\n")  # Log message to indicate the start of data cleaning

# Filter for valid rows and retain only relevant columns
products_clean <- products_raw %>%
  filter(!is.na(name), !is.na(category), !is.na(image_path)) %>%  # Remove rows with missing values in key columns
  select(name, category, image_path)  # Keep only necessary columns for the database

cat("Data cleaned. Number of valid rows:", nrow(products_clean), "\n")  # Log the number of cleaned rows

# Step 4: Connect to SQLite database
cat("Connecting to SQLite database 'closet.db'...\n")  # Log message for database connection
conn <- dbConnect(SQLite(), dbname = "closet.db")  # Establish a connection to the SQLite database

# Step 5: Define schema (if not exists)
cat("Defining database schema...\n")  # Log message for schema definition
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS closet (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Auto-incrementing ID for each record
  name TEXT,                             -- Name of the product
  category TEXT,                         -- Product category (e.g., Top, Bottom)
  image_path TEXT                        -- Path or URL of the product image
);")  # SQL command to create the table if it doesn't already exist

# Step 6: Insert cleaned data into the database
cat("Inserting cleaned data into 'closet' table...\n")  # Log message for data insertion
dbWriteTable(conn, "closet", products_clean, overwrite = TRUE, row.names = FALSE)  # Write the cleaned data into the database

# Step 7: Validate insertion
cat("Validating data insertion...\n")  # Log message for validation
record_count <- dbGetQuery(conn, "SELECT COUNT(*) AS count FROM closet;")  # Query to count the number of records in the table
cat("Number of records in 'closet' table:", record_count$count, "\n")  # Log the record count

# Step 8: Disconnect from the database
cat("Disconnecting from database...\n")  # Log message for database disconnection
dbDisconnect(conn)  # Close the database connection
cat("ETL process complete.\n")  # Final log message to indicate completion of the ETL process