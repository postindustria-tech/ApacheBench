#!/bin/bash

# Constants
CAL_OUT=calibrate.out
PRO_OUT=process.out
AB=`dirname $0`/ab
UAS=`dirname $0`/uas.csv
ALLOWED_OVERHEAD_MS=200

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--host)
    HOST="$2"
    shift # past argument
    shift # past value
    ;;
    -n|--passes)
    PASSES="$2"
    shift # past argument
    shift # past value
    ;;
	-s|--service-start)
    SERVICE_START="$2"
    shift # past argument
    shift # past value
    ;;
    -c|--calibration-endpoint)
    CAL_END="$2"
    shift # past argument
    shift # past value
    ;;
    -p|--process-endpoint)
    PRO_END="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    shift # past argument
    ;;
esac
done

if [[ -z ${HOST} ]] || [[ -z ${PASSES} ]] || [[ -z ${CAL_END} ]] || [[ -z ${PRO_END} ]]
then
    echo "Some arguments were missing."
    echo ""
    echo "Expected:"
    echo "    -h | --host                   : root host to call e.g. localhost:3000"
    echo "    -n | --passes                 : number of passes i.e. the number of calls to the endpoint"
	echo "    -s | --service-start          : command to start the web service e.g. \"php -S localhost:3000\""
    echo "    -c | --calibration-endpoint   : endpoint path to use for calibration on the host e.g. test/calibrate"
    echo "    -p | --process-endpoint       : endpoint path to use for the process pass on the host e.g. test/process"
	echo ""
	echo "For example:"
	echo "    runPerf.bat -host localhost:3000 -passes 1000 -service-start \"php -S localhost:3000\" ..."
    exit 0
fi

echo "Host                     = ${HOST}"
echo "Passes                   = ${PASSES}"
echo "Service Start            = ${SERVICE_START}"
echo "Calibration Endpoint     = ${CAL_END}"
echo "Process Endpoint         = ${PRO_END}"

# Function for arithmetic
calc() { awk "BEGIN{print $*}"; }


# Start the service
echo "Starting Service"
${SERVICE_START} 2>service.error.out 1>service.out &
SERVICE_PID=$!

# Wait for the service to start up
echo "Waiting up to 60 seconds for $HOST/$CAL_END"
if ! command -v curl &> /dev/null
then
  sleep 15
else
  tries=0
  while [[ "$(curl -o /dev/null -s -w '%{http_code}' $HOST/$CAL_END)" -ne 200 ]] && [[ $tries -le 12 ]]; do  
    let "tries++"
    sleep 5
  done
fi

# Run the benchmarks
echo "Running calibration"
$AB -U $UAS -q -n $PASSES $HOST/$CAL_END >$CAL_OUT
echo "Running processing"
$AB -U $UAS -q -n $PASSES $HOST/$PRO_END >$PRO_OUT

# Stop the service
kill $SERVICE_PID
wait $SERVICE_PID 2>&1

# Check no requests failed in calibration
FAILED_CAL=`cat $CAL_OUT | grep "Failed requests" | sed -En "s/Failed requests: *([0-9]*)/\1/p"`
if [ $FAILED_CAL -ne 0 ]
  then
    echo "There were $FAILED_CAL calibration requests" 1>&2
fi

# Check no requests failed in processing
FAILED_PRO=`cat $PRO_OUT | grep "Failed requests" | sed -En "s/Failed requests: *([0-9]*)/\1/p"`
if [ $FAILED_PRO -ne 0 ]
  then
    echo "There were $FAILED_PRO process requests" 1>&2
fi

# Check no requests were non-200 (e.g. 404) in calibration
NON200_CAL=`cat $CAL_OUT | grep "Non-2xx responses"`
if [ ! -z "$NON200_CAL" ]
  then
    NON200_CAL_COUNT=`echo $NON200_CAL | sed -En "s/Non-2xx responses: *([0-9]*)/\1/p"`
    echo "There were $NON200_CAL_COUNT non-200 calibration requests" 1>&2
fi

# Check no requests were non-200 (e.g. 404) in processing
NON200_PRO=`cat $PRO_OUT | grep "Non-2xx responses"`
if [ ! -z "$NON200_PRO" ]
  then
    NON200_PRO_COUNT=`echo $NON200_PRO | sed -En "s/Non-2xx responses: *([0-9]*)/\1/p"`
    echo "There were $NON200_PRO_COUNT non-200 process requests" 1>&2
fi

# Get the time for calibration
CAL_TIME=`cat $CAL_OUT | grep "Time taken for tests" | sed -En "s/Time taken for tests: *([0-9]*\.[0-9]*) seconds/\1/p"`
CAL_TIME_PR=`calc $CAL_TIME / $PASSES`
echo "Calibration time: $CAL_TIME s ($CAL_TIME_PR s per request)"

# Get the time for processing
PRO_TIME=`cat $PRO_OUT | grep "Time taken for tests" | sed -En "s/Time taken for tests: *([0-9]*\.[0-9]*) seconds/\1/p"`
PRO_TIME_PR=`calc $PRO_TIME / $PASSES`
echo "Processing time: $PRO_TIME s ($PRO_TIME_PR s per request)"

# Calculate the processing overhead
DIFF=`calc $PRO_TIME - $CAL_TIME`
OVERHEAD_S=`calc $DIFF / $PASSES`
OVERHEAD_MS=`calc $OVERHEAD_S \* 1000`
echo "Processing overhead is $OVERHEAD_MS ms per request"

# Check the overhead was small enough
LT=`calc $OVERHEAD_MS \< $ALLOWED_OVERHEAD_MS`
if [ $LT -eq 0 ]
  then
    echo "Overhead was over $ALLOWED_OVERHEAD_MS" 1>&2
fi
