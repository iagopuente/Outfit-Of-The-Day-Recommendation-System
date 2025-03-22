# Load necessary libraries
library(httr)        # For making HTTP requests
library(jsonlite)    # For parsing JSON data
library(dplyr)       # For data manipulation

# Step 1: Define the API endpoint URL for ASOS Men's New In page
url <- 'https://www.asos.com/api/product/search/v2/categories/27110?store=COM&lang=en-GB&currency=GBP&sizeSchema=UK&offset=0&limit=72&sort=freshness'

# Step 2: Fetch the JSON data from the API
response <- GET(url)

# Check if the request was successful
if (status_code(response) != 200) stop("Failed to retrieve data")

# Parse the JSON content
data <- content(response, as = "text", encoding = "UTF-8")
json_data <- fromJSON(data)

# Step 3: Extract products data
products <- json_data$products  # Extract the list of products from the JSON response

# Step 4: Extract relevant fields
product_names <- products$name  # Extract product names
product_links <- paste0("https://www.asos.com/", products$url)  # Construct full product URLs
image_urls <- ifelse(grepl("^https://", products$imageUrl), products$imageUrl, paste0("https://", products$imageUrl))  # Ensure valid image URLs

# Categorize items into required types
item_types <- ifelse(grepl("trouser|pant|skirt|jeans", tolower(product_names)), "Bottom",
                     ifelse(grepl("shirt|blouse|tee|top|sweater|jumper|hoodie", tolower(product_names)), "Top",
                            ifelse(grepl("jacket|coat", tolower(product_names)), "Outerwear",
                                   ifelse(grepl("shoes|sneaker|boots|loafers|trainers|trainer|slipper", tolower(product_names)), "Shoes",
                                          ifelse(grepl("umbrella|sunglasses|bag|scarf|hat|cap|gloves|beanie", tolower(product_names)), "Accessories",
                                                 "Others")))))

# Step 5: Combine into a data frame
asos_products <- data.frame(
  name = product_names,        # Product name
  link = product_links,        # Product link
  image_path = image_urls,     # Image URL
  category = item_types,       # Assigned category
  stringsAsFactors = FALSE
)

# Save the data to a CSV file (overwrite the raw data file for ETL)
write.csv(asos_products, "products_raw.csv", row.names = FALSE)
cat("Updated 'products_raw.csv' with new product data.\n")

# Step 6: Create a function to sanitize filenames
sanitize_filename <- function(name, max_length = 50) {
  name <- gsub("[^a-zA-Z0-9]", "_", name)  # Replace invalid characters with underscores
  substr(name, 1, max_length)             # Truncate the filename to the specified length
}

# Step 7: Define the base directory for images
base_dir <- "C:/Users/bolix/OneDrive - Universitat Ramón Llull/OneDrive Esade/Masters + GMAT/LBS/Subjects/Data Management/Final project assignment - Outfit Of The Day Recommendation System/asos_images"

# Check base directory creation
if (!dir.exists(base_dir)) {
  if (!dir.create(base_dir, recursive = TRUE)) {
    stop("Failed to create base directory: ", base_dir)  # Exit if directory creation fails
  }
}

# Step 8: Group products by type
asos_products_grouped <- asos_products %>%
  group_by(category) %>%  # Group products by their category
  ungroup()               # Ungroup after grouping for further operations

# Step 9: Download unique images and organize into folders by type
failed_downloads <- c()  # Initialize a list to track failed downloads

for (i in seq_len(nrow(asos_products_grouped))) {
  item <- asos_products_grouped[i, ]
  type_folder <- file.path(base_dir, item$category)  # Determine the folder for the category
  
  # Ensure the type-specific folder exists
  if (!dir.exists(type_folder)) {
    cat("Creating type folder:", type_folder, "\n")
    dir.create(type_folder, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Generate a unique filename based only on the sanitized name
  safe_name <- sanitize_filename(item$name)
  file_name <- file.path(type_folder, paste0(safe_name, ".jpg"))
  
  # Skip if file already exists
  if (file.exists(file_name)) {
    cat("File already exists (skipping):", file_name, "\n")
    next
  }
  
  # Attempt to download the image
  cat("Attempting to download:", item$image_path, "to", file_name, "\n")
  tryCatch(
    {
      img_response <- GET(
        item$image_path,
        user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"),
        timeout(30)  # Set a timeout of 30 seconds
      )
      
      # Check the HTTP status code
      if (status_code(img_response) == 200) {
        writeBin(content(img_response, "raw"), file_name)  # Save the image to the file
        cat("Successfully downloaded:", item$image_path, "\n")
      } else {
        cat("Failed to download (HTTP Error):", item$image_path, "\n")
        failed_downloads <- c(failed_downloads, item$image_path)  # Track failed download
      }
    },
    error = function(e) {
      cat("Failed to download:", item$image_path, "\nError:", e$message, "\n")
      failed_downloads <- c(failed_downloads, item$image_path)  # Track failed download
    }
  )
}

# Step 10: Log failed downloads
if (length(failed_downloads) > 0) {
  log_file <- file.path(base_dir, "failed_downloads.log")
  writeLines(failed_downloads, log_file)  # Log the failed downloads to a file
  cat("Logged failed downloads to:", log_file, "\n")
}

cat("Product scraping and image downloading complete!\n")