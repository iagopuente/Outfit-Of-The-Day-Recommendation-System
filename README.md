# Outfit of the Day Recommendation System

## Project Description
The *Outfit of the Day Recommendation System* is an automated tool that scrapes clothing data, fetches real-time weather information, and recommends a complete outfit based on weather conditions. It generates a visual representation of the recommended outfit, making it convenient for users to plan their attire.

---

## Table of Contents
1. [Prerequisites and Dependencies](#prerequisites-and-dependencies)
2. [Installation and Setup Instructions](#installation-and-setup-instructions)
3. [Project Structure Overview](#project-structure-overview)
4. [Usage Instructions](#usage-instructions)
5. [Recommendation Logic Explanation](#recommendation-logic-explanation)
6. [Output Description](#output-description)
7. [Additional Features](#additional-features)
8. [Troubleshooting and FAQs](#troubleshooting-and-faqs)
9. [Dependencies and Package Installation](#dependencies-and-package-installation)
10. [License Information](#license-information)
11. [Contact Information](#contact-information)

---

## Prerequisites and Dependencies

### Software and Libraries
- **R** (Version >= 4.4.0)
- **SQLite**
- **Bash shell**
- R Packages:
  - `rvest`
  - `httr`
  - `jsonlite`
  - `DBI`
  - `RSQLite`
  - `plumber`
  - `dplyr`
  - `magick`

### System Requirements
- Operating System: Windows, macOS, or Linux.
- Internet connection for fetching product data and weather data.
- Access to the [Weatherstack API](https://weatherstack.com/) for real-time weather data.

---

## Installation and Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd outfit-of-the-day
   ```

2. **Install Required R Packages**
   Open R and run the following command:
   ```R
   install.packages(c("rvest", "httr", "jsonlite", "DBI", "RSQLite", "plumber", "dplyr", "magick"))
   ```

3. **Set Up Weatherstack API Key**
   - Sign up at [Weatherstack API](https://weatherstack.com/) to get your API key.
   - Pass your API key as an argument to the Bash script or export it as an environment variable:
     ```bash
     export YOUR_ACCESS_KEY="your_api_key"
     ```

4. **Directory Setup**
   Ensure the following directories exist:
   - `images/`: To store product images.
   - `closet.db`: SQLite database created during the ETL process.

---

## Project Structure Overview

### Major Scripts and Files
- **`product_scraping.R`**: Scrapes product data and downloads images.
- **`weatherstack_api.R`**: Fetches current weather data using the Weatherstack API.
- **`etl.R`**: Cleans data and populates the SQLite database.
- **`ootd_api.R`**: Defines API endpoints using Plumber.
- **`run_ootd_api.R`**: Starts the API server.
- **`run_pipeline.sh`**: Bash script that automates the entire pipeline.

### Other Files
- **`closet.db`**: SQLite database storing the product catalog.
- **`images/`**: Directory containing downloaded product images.
- **`ootd_plot.png`**: Output image showing the recommended outfit(s).
- **`pipeline_log.txt`**: Log file capturing the pipeline's execution status.

---

## Usage Instructions

### Run the Complete Pipeline
Execute the pipeline to generate outfit recommendations:
```bash
./run_pipeline.sh YOUR_ACCESS_KEY
```

### Start the API Server
Run the API server independently:
```bash
Rscript run_ootd_api.R
```

### Access API Endpoints
- **/ootd**: Generates the outfit of the day.
  ```bash
  curl "http://localhost:8000/ootd" --output ootd_plot.png
  ```
- **/rawdata**: Fetches raw product data in JSON format.
  ```bash
  curl "http://localhost:8000/rawdata"
  ```

---

## Recommendation Logic Explanation

- **Temperature > 25°C**: Light clothing (e.g., t-shirts, shorts, sandals).
- **15°C ≤ Temperature ≤ 25°C**: Comfortable clothing (e.g., jeans, trainers, sweaters).
- **Temperature < 15°C**: Warm clothing (e.g., coats, boots).
- **Rain**: Includes raincoat or umbrella.
- **Sunny**: Suggests sunglasses.

Each outfit is tailored to match the weather description and temperature.

---

## Output Description

- **`ootd_plot.png`**: 
  - A mosaic image showing the recommended outfit items.
  - Includes:
    - Weather details (e.g., temperature, description).
    - Images for outerwear, top, bottom, shoes, and accessories.
    - Date of the recommendation.
- Multiple outfit suggestions are generated in a single API call.

---

## Additional Features

- **Expanded Closet**: Over 50 products in the `closet.db` database.
- **Multiple Outfit Suggestions**: `/ootd` endpoint generates two or more outfit recommendations in a single call.
- **Optimized API**: Faster response and efficient data handling.

---

## Troubleshooting and FAQs

### Common Issues
- **API Key Errors**: Ensure the correct Weatherstack API key is provided.
- **Missing Dependencies**: Reinstall required R packages using:
  ```R
  install.packages(c("rvest", "httr", "jsonlite", "DBI", "RSQLite", "plumber", "dplyr", "magick"))
  ```
- **Port Conflicts**: Use a different port if `8000` is unavailable:
  ```bash
  Rscript run_ootd_api.R --port=8080
  ```

### Tips
- Verify that the `closet.db` database contains sufficient data.
- Check `pipeline_log.txt` for error details during execution.

---

## Dependencies and Package Installation

To install the required R packages, run:
```R
install.packages(c("rvest", "httr", "jsonlite", "DBI", "RSQLite", "plumber", "dplyr", "magick"))
```

System-level dependencies:
- **SQLite**: Pre-installed on most systems. Install via:
  - Linux: `sudo apt install sqlite3`
  - macOS: `brew install sqlite`
  - Windows: Download from [SQLite.org](https://www.sqlite.org/).

---

## Contact Information

For questions or feedback:
- **Name**: Iago Puente Esteban
- **Email**: iagop.mam2025@london.edu

---