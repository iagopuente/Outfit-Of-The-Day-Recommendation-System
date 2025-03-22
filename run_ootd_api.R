# Load the Plumber library
library(plumber)  # Plumber is used to create and run the API server

# Start the Plumber API server
pr <- plumber::plumb("ootd_api.R")  # Load the API logic from the file 'ootd_api.R'
pr$run(port = 8000, host = "0.0.0.0")  # Start the API server on port 8000, accessible on all network interfaces