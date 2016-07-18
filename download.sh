#!/bin/bash

download_user=test
download_password=test

# Properties file is needed
PROPERTIES_FILE="./download.properties"
if [ ! -f "$PROPERTIES_FILE" ]; then
    echo "Properties file $PROPERTIES_FILE not found!"
    exit 3
fi

source $PROPERTIES_FILE

# Command line options parsing
# http://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

getopt --test > /dev/null
if [[ $? != 4 ]]; then
    echo "I'm sorry, `getopt --test` failed in this environment."
    exit 1
fi

SHORT=ci:
LONG=createdatabase,insert:

# -temporarily store output to be able to check for errors
# -activate advanced mode getopt quoting e.g. via “--options”
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
if [[ $? != 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi

# use eval with "$PARSED" to properly handle the quoting
eval set -- "$PARSED"

# Log in to Polar Flow
function login {
    # Login flowhun
    echo curl -k -L -b kake3 -c kake3 -o out_login.html -d "email=$download_user&password=$download_password" https://flow.polar.com/login
}

# Load activity data from Polar Flow (needs login)
# Outputs an out_$date.html, that contains the html data received from the service
# @param1: the data date (e.g. "1.7.2016")
function loadData {
    local date=$1

    # Lataa päivän aktiivisuusdata
    curl -k -L -b kake3 -c kake3 -o out_$date.html https://flow.polar.com/activity/summary/$date/$date/day?_=0
}

# Extract the activity data from the downloaded dataset.
# This uses the data downloaded from Polar Flow service. The method expects the data be in out_$date.html
# Outputs an data_$date.data file that contains the activity data
# @param1 the data date
function extractData {
    # Tästä sitten uuden metodin alku
    local input="out_$1.html"
    local output="data_$1.data"

    # Hae ladatusta html:sta halutun datan alku ja loppukohta
    line1=$(awk '/var data = \[/{ print NR; exit}' $input)
    line2=$(awk '/var total = 0;/{ print NR; exit}' $input)

    # Vähän hienosäätöä riveille
    # TODO Poista enemmän rivejä alusta
    line1=`expr $line1 - 1`
    line2=`expr $line2 - 1`

    # Hae sedillä data, parametrisoi input ja output
    sed -n "$line1,$line2"'p' $input > $output

}


function insertDataToDatabase {

    local insertDate=$1

    # grep the interesting data from the file
    # combine the two sequential lines to one
    # get only the interesting data from the line
    # get rid of the extra commas
    data=($(grep '\(y\|activityClass\)' data_1.7.2016.data | sed 'N;s/\n/ /' | awk '{print $2 $4}' | sed 's/,/ /g'))

    local seconds

    for ((i = 0; i < ${#data[@]}; i=i+2))
    do
      local sec=`expr ${data[$i]} / 1000`
      seconds=`expr $seconds + $sec`
      local SQL="INSERT INTO activities (time, zone) VALUES (datetime('${insertDate}', '+$seconds seconds') ,${data[$i+1]});"
      sqlite3 /tmp/activity.db "$SQL"
    done

}

# Tästä alkaa itte suoritus

# CREATE TABLE zone_enum(
#         zone TEXT NOT NULL, 
#         value INTEGER NOT NULL);
# 
# CREATE TABLE activities (
#         time TIMESTAMP NOT NULL, 
#         zone TEXT NOT NULL,
#         fixedZone TEXT NOT NULL,
#         FOREIGN KEY(zone) REFERENCES zone_enum(zone),
#         FOREIGN KEY(fixedZone) REFERENCES zone_enum(zone));


login
#loadData "1.7.2016"
#extractData "1.7.2016"
#insertDataToDatabase "2016-07-01"


