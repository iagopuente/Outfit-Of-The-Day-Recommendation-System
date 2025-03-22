# Load necessary libraries
library(RSQLite)     # For SQLite database connectivity
library(dplyr)       # For data manipulation
library(magick)      # For image processing
library(httr)        # For making HTTP requests
library(plumber)     # For creating REST API endpoints

# Global variables
db_file <- "closet.db"                  # SQLite database file name
output_file <- "ootd_plot.png"          # Output file for the outfit plot
weather_data <- readRDS("weather_data.rds")  # Load saved weather data
temperature <- weather_data$current$temperature  # Extract current temperature
weather_desc <- tolower(weather_data$current$weather_descriptions)  # Extract and format weather description

# Function to create a mosaic overlay for outfit
create_outfit_overlay <- function(outfit, weather_desc, temperature, output_file = "ootd_plot.png") {
  tryCatch({
    # Define canvas size and grid layout
    canvas <- image_blank(width = 1200, height = 1400, color = "white")  # Blank canvas for the outfit image
    cell_width <- 300  # Width of each cell in the mosaic
    cell_height <- 300 # Height of each cell in the mosaic
    x_offsets <- c(0, cell_width, 2 * cell_width, 0, cell_width)  # X-offsets for grid positioning
    y_offsets <- c(200, 200, 200, 500, 500)                      # Y-offsets for grid positioning below weather and date annotations
    
    categories <- c("outerwear", "top", "bottom", "shoes", "accessory")  # Outfit categories to display
    
    # Add weather and date annotations at the top of the canvas
    canvas <- canvas %>%
      image_annotate(
        text = paste("Weather:", weather_desc, "|", temperature, "°C"),
        size = 40, gravity = "North", color = "black", location = "+0+50"
      ) %>%
      image_annotate(
        text = paste("Date:", Sys.Date()),
        size = 40, gravity = "North", color = "black", location = "+0+100"
      )
    
    # Add each category's image to the grid
    for (i in seq_along(categories)) {
      category <- categories[i]
      if (!is.null(outfit[[category]]) && nrow(outfit[[category]]) > 0) {
        tryCatch({
          # Load image for the category
          image_url <- outfit[[category]]$image_path[1]  # Get the image URL from the database query
          response <- httr::GET(
            url = image_url,
            httr::add_headers("User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
          )
          if (httr::status_code(response) != 200) {
            stop("Failed to fetch image.")  # Stop if the image fetch fails
          }
          item_image <- image_read(httr::content(response, "raw")) %>% image_resize("300x300")  # Resize the image
        }, error = function(e) {
          # Placeholder for missing images
          message("Error loading image for ", category, ": ", e$message)
          item_image <- image_blank(width = cell_width, height = cell_height, color = "gray") %>%
            image_annotate(text = paste("No", category), size = 30, color = "red")
        })
      } else {
        # Placeholder for missing categories
        item_image <- image_blank(width = cell_width, height = cell_height, color = "gray") %>%
          image_annotate(text = paste("No", category), size = 30, color = "red")
      }
      
      # Annotate category name in white and composite onto canvas
      annotated_image <- item_image %>%
        image_annotate(
          text = toupper(category),
          size = 20, gravity = "South", color = "white", location = "+0+10"
        )
      canvas <- image_composite(canvas, annotated_image, offset = paste0("+", x_offsets[i], "+", y_offsets[i]))
    }
    
    # Save the mosaic to file
    image_write(canvas, output_file)
    message("Image successfully created and saved to: ", output_file)
  }, error = function(e) {
    message("Error creating outfit overlay: ", e$message)
  })
}

# Function to generate outfit recommendations
generate_outfit <- function() {
  conn <- dbConnect(SQLite(), dbname = db_file)  # Connect to SQLite database
  on.exit(dbDisconnect(conn))  # Ensure the connection is closed after execution
  
  outfit <- list()  # Initialize the outfit list
  
  # Apply temperature-based rules
  if (temperature > 25) {
    # Recommendations for hot weather
    outfit$top <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Top' AND name LIKE '%shirt%' LIMIT 1")
    outfit$bottom <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Bottom' AND name LIKE '%shorts%' LIMIT 1")
    outfit$shoes <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Shoes' AND name LIKE '%sandals%' LIMIT 1")
  } else if (temperature >= 15 && temperature <= 25) {
    # Recommendations for mild weather
    outfit$top <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Top' LIMIT 1")
    outfit$bottom <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Bottom' AND name LIKE '%jeans%' LIMIT 1")
    outfit$shoes <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Shoes' AND name LIKE '%trainer%' LIMIT 1")
    outfit$outerwear <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Outerwear' LIMIT 1")
  } else {
    # Recommendations for cold weather
    outfit$top <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Top' LIMIT 1")
    outfit$bottom <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Bottom' LIMIT 1")
    outfit$shoes <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Shoes' LIMIT 1")
    outfit$outerwear <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Outerwear' LIMIT 1")
  }
  
  # Apply weather condition-based rules
  if (grepl("rain", weather_desc)) {
    # Add an umbrella for rainy weather
    outfit$accessory <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Accessories' AND name LIKE '%umbrella%' LIMIT 1")
  } else if (grepl("sunny", weather_desc)) {
    # Add sunglasses for sunny weather
    outfit$accessory <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Accessories' AND name LIKE '%sunglasses%' LIMIT 1")
  } else {
    # Default accessory
    outfit$accessory <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Accessories' LIMIT 1")
  }
  
  return(outfit)
}

# Plumber API endpoint to get the outfit of the day
#* @apiTitle Outfit Recommendation API
#* Get Outfit of the Day
#* @get /ootd
#* @serializer contentType list(type="image/png")
function(res) {
  outfit <- generate_outfit()  # Generate outfit recommendations
  create_outfit_overlay(outfit, weather_desc, temperature, output_file)  # Create the outfit mosaic
  res$body <- readBin(output_file, "raw", file.info(output_file)$size)  # Return the image as the response body
  res$setHeader("Content-Type", "image/png")  # Set the response content type
  res
}

# Plumber API endpoint to get raw product data
#* @get /rawdata
function() {
  conn <- dbConnect(SQLite(), dbname = db_file)  # Connect to SQLite database
  on.exit(dbDisconnect(conn))  # Ensure the connection is closed after execution
  data <- dbGetQuery(conn, "SELECT * FROM closet")  # Fetch all data from the 'closet' table
  jsonlite::toJSON(data, pretty = TRUE)  # Return the data as pretty-printed JSON
}