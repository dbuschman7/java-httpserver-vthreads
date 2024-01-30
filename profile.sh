#!/bin/bash
set -ex

MODULE_OUT="httpsrvimg"
JLINK_BIN="$(pwd)/${MODULE_OUT}/bin/java"

WRK_BUILD="wrk_build"
WRK_BIN="$(pwd)/${WRK_BUILD}/wrk"

getCurrentTime() {
    date +"%s.%3N"
}

buildJavaModule() { 
   echo "Build Java App"
   rm -fr $MODULE_OUT 
   javac -d mods/ src/httpsrv/*.java src/module-info.java
   jlink --module-path $JAVA_HOME/jmods:mods --add-modules httpsrv --output $MODULE_OUT
   ls -la $JLINK_BIN
} 

buildWrk() { 
   echo "Build wrk load tester"
   if [[ -e "$WRK_BUILD" ]]; then 
     echo "Wrk appears to already be available"
     return 0
   fi 

   git clone https://github.com/wg/wrk.git $WRK_BUILD
   cd $WRK_BUILD
   make
}

runHttpServer() {
    $JLINK_BIN -Dsun.net.httpserver.nodelay=true -m httpsrv/httpsrv.Hello
} 

profileHttpServer() {
    read line # wait for "ready" line emitted by server
    local javaEndTime=$(getCurrentTime)
    local statusCode=$(makeCurlRequest)
    local curlEndTime=$(getCurrentTime)

    echo "$1 $javaEndTime $curlEndTime $statusCode"
    pkill java
}

makeCurlRequest() {
    curl "http://localhost:8080/" -o /dev/null -s -w "%{http_code}"
}

measureExecutionTimes() {
    echo "Run Simple tests" 
    for i in {1..10}; do
        local startTime=$(getCurrentTime)
        runHttpServer | profileHttpServer $startTime
    done | processTimings
}

processTimings() {
    awk '{
        d1=$2-$1
        d2=$3-$1
        s1+=d1
        s2+=d2
        printf "%f, %f, %d\n", d1, d2, $4
    }
    END {
        printf "---\n%f, %f\n", s1/NR, s2/NR
    }'
}

loadTest() {
  read line # wait for "ready" line emitted by server
  echo "Run load test" 
  $WRK_BIN --latency -d 60s -c 100 -t 8 http://localhost:8080/ 
  pkill java
} 


# MAIN
# ##############################
 buildWrk
 buildJavaModule
# measureExecutionTimes
 runHttpServer | loadTest
# ##############################

echo "DONE"
