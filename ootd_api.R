# Load necessary libraries
library(RSQLite)  # For database operations
library(dplyr)    # For data manipulation
library(magick)   # For creating and editing images
library(httr)     # For making HTTP requests
library(plumber)  # For building APIs

# Global variables
db_file <- "closet.db"                # SQLite database file for storing product data
output_file <- "ootd_plot.png"        # Output file name for the outfit image
weather_data <- readRDS("weather_data.rds")  # Load weather data from an RDS file
temperature <- weather_data$current$temperature  # Extract current temperature
weather_desc <- tolower(weather_data$current$weather_descriptions)  # Extract and convert weather description to lowercase

# Function to create a mosaic overlay for the outfit
create_outfit_overlay <- function(outfit, weather_desc, temperature, output_file = "ootd_plot.png") {
  tryCatch({
    # Define canvas size and grid layout for the outfit image
    canvas <- image_blank(width = 1200, height = 1400, color = "white")  # Blank canvas for the mosaic
    cell_width <- 300  # Width of each grid cell
    cell_height <- 300  # Height of each grid cell
    x_offsets <- c(0, cell_width, 2 * cell_width, 0, cell_width)  # Horizontal offsets for grid cells
    y_offsets <- c(200, 200, 200, 500, 500)  # Vertical offsets for grid cells below the weather/date text
    
    categories <- c("outerwear", "top", "bottom", "shoes", "accessory")  # Categories to include in the outfit
    
    # Add weather and date annotations to the top of the canvas
    canvas <- canvas %>%
      image_annotate(
        text = paste("Weather:", weather_desc, "|", temperature, "°C"),  # Weather information annotation
        size = 40, gravity = "North", color = "black", location = "+0+50"
      ) %>%
      image_annotate(
        text = paste("Date:", Sys.Date()),  # Date annotation
        size = 40, gravity = "North", color = "black", location = "+0+100"
      )
    
    # Add images for each category to the grid
    for (i in seq_along(categories)) {
      category <- categories[i]  # Current category being processed
      if (!is.null(outfit[[category]]) && nrow(outfit[[category]]) > 0) {
        tryCatch({
          # Load image from the URL for the current category
          image_url <- outfit[[category]]$image_path[1]
          response <- httr::GET(
            url = image_url,
            httr::add_headers("User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
          )
          if (httr::status_code(response) != 200) {
            stop("Failed to fetch image.")  # Error if image cannot be fetched
          }
          item_image <- image_read(httr::content(response, "raw")) %>% image_resize("300x300")  # Resize the image to fit the grid
        }, error = function(e) {
          # Create a placeholder if the image cannot be loaded
          message("Error loading image for ", category, ": ", e$message)
          item_image <- image_blank(width = cell_width, height = cell_height, color = "gray") %>%
            image_annotate(text = paste("No", category), size = 30, color = "red")
        })
      } else {
        # Create a placeholder if the category has no data
        item_image <- image_blank(width = cell_width, height = cell_height, color = "gray") %>%
          image_annotate(text = paste("No", category), size = 30, color = "red")
      }
      
      # Annotate the category name and place the image on the canvas
      annotated_image <- item_image %>%
        image_annotate(
          text = toupper(category),  # Add category name annotation
          size = 20, gravity = "South", color = "white", location = "+0+10"
        )
      canvas <- image_composite(canvas, annotated_image, offset = paste0("+", x_offsets[i], "+", y_offsets[i]))
    }
    
    # Save the final outfit image
    image_write(canvas, output_file)
    message("Image successfully created and saved to: ", output_file)
  }, error = function(e) {
    # Log errors if the outfit image cannot be created
    message("Error creating outfit overlay: ", e$message)
  })
}

# Function to generate outfit recommendations based on weather
generate_outfit <- function() {
  conn <- dbConnect(SQLite(), dbname = db_file)  # Connect to the SQLite database
  on.exit(dbDisconnect(conn))  # Ensure the database connection is closed
  
  outfit <- list()  # Initialize an empty list to store the outfit
  
  # Determine outfit based on temperature
  if (temperature > 25) {
    # Outfit for hot weather
    outfit$top <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Top' AND name LIKE '%shirt%' LIMIT 1")
    outfit$bottom <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Bottom' AND name LIKE '%shorts%' LIMIT 1")
    outfit$shoes <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Shoes' AND name LIKE '%sandals%' LIMIT 1")
  } else if (temperature >= 15 && temperature <= 25) {
    # Outfit for mild weather
    outfit$top <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Top' LIMIT 1")
    outfit$bottom <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Bottom' AND name LIKE '%jeans%' LIMIT 1")
    outfit$shoes <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Shoes' AND name LIKE '%trainer%' LIMIT 1")
    outfit$outerwear <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Outerwear' LIMIT 1")
  } else {
    # Outfit for cold weather
    outfit$top <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Top' LIMIT 1")
    outfit$bottom <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Bottom' LIMIT 1")
    outfit$shoes <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Shoes' LIMIT 1")
    outfit$outerwear <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Outerwear' LIMIT 1")
  }
  
  # Add accessories based on specific weather conditions
  if (grepl("rain", weather_desc)) {
    outfit$accessory <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Accessories' AND name LIKE '%umbrella%' LIMIT 1")
  } else if (grepl("sunny", weather_desc)) {
    outfit$accessory <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Accessories' AND name LIKE '%sunglasses%' LIMIT 1")
  } else {
    outfit$accessory <- dbGetQuery(conn, "SELECT * FROM closet WHERE category = 'Accessories' LIMIT 1")
  }
  
  return(outfit  # Return the generated outfit
  )
}

# Plumber API endpoint to get the outfit of the day
#* @apiTitle Outfit Recommendation API
#* Get Outfit of the Day
#* @get /ootd
#* @serializer contentType list(type="image/png")
function(res) {
  outfit <- generate_outfit()  # Generate the outfit
  create_outfit_overlay(outfit, weather_desc, temperature, output_file)  # Create the outfit image
  res$body <- readBin(output_file, "raw", file.info(output_file)$size)  # Read the generated image as binary
  res$setHeader("Content-Type", "image/png")  # Set response header to PNG
  res  # Return the response
}

# Plumber API endpoint to get raw product data
#* @get /rawdata
function() {
  conn <- dbConnect(SQLite(), dbname = db_file)  # Connect to the database
  on.exit(dbDisconnect(conn))  # Ensure the database connection is closed
  data <- dbGetQuery(conn, "SELECT * FROM closet")  # Fetch all product data
  jsonlite::toJSON(data, pretty = TRUE)  # Return the data in JSON format
}