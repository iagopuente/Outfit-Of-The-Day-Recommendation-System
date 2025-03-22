#!/bin/bash

# Usage: ./run_pipeline.sh YOUR_ACCESS_KEY

# Step 1: Input Validation
if [ -z "$1" ]; then
    echo "Usage: $0 YOUR_ACCESS_KEY"
    exit 1
fi

# Step 2: Export API Key
YOUR_ACCESS_KEY=$1
export YOUR_ACCESS_KEY

# Step 3: Log Start
LOG_FILE="pipeline_log.txt"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting pipeline..." > $LOG_FILE

# Step 4: Run Product Scraping
echo "$(date '+%Y-%m-%d %H:%M:%S') - Running product scraping..." >> $LOG_FILE
Rscript product_scraping.R
if [ $? -ne 0 ]; then
    echo "Error in product scraping. Check logs."
    exit 1
fi

# Step 5: Fetch Weather Data
echo "$(date '+%Y-%m-%d %H:%M:%S') - Fetching weather data..." >> $LOG_FILE
Rscript weatherstack_api.R
if [ $? -ne 0 ]; then
    echo "Error in fetching weather data. Check logs."
    exit 1
fi

# Step 6: Run ETL Process
echo "$(date '+%Y-%m-%d %H:%M:%S') - Running ETL process..." >> $LOG_FILE
Rscript etl.R
if [ $? -ne 0 ]; then
    echo "Error in ETL process. Check logs."
    exit 1
fi

# Step 7: Start the API
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting the API..." >> $LOG_FILE
Rscript run_ootd_api.R &
API_PID=$!
sleep 5  # Allow the API to initialize

# Step 8: Call the /ootd Endpoint
echo "$(date '+%Y-%m-%d %H:%M:%S') - Fetching outfit of the day..." >> $LOG_FILE
curl -s "http://localhost:8000/ootd" --output ootd_plot.png
if [ $? -ne 0 ]; then
    echo "Error in calling the /ootd endpoint. Check logs."
    kill $API_PID
    exit 1
fi
echo "Outfit of the Day plot saved as ootd_plot.png"

# Step 9: Cleanup
kill $API_PID
echo "$(date '+%Y-%m-%d %H:%M:%S') - Pipeline completed successfully." >> $LOG_FILE