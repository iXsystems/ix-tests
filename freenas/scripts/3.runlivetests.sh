#!/usr/bin/env bash
# Author: Kris Moore
# License: BSD
# Location for tests into REST API of FreeNAS 9.10
# Resty Docs: https://github.com/micha/resty
# jsawk: https://github.com/micha/jsawk

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Set variable to call jsawk utility
JSAWK="${PROGDIR}/../utils/jsawk -j js24"

# Test Module directory
TDIR="${PROGDIR}/9.10-live-tests"

# Source our Testing functions
. ${PROGDIR}/scripts/functions-tests.sh

#################################################################
# Run the tests now!
#################################################################

# Set the default test type
TESTSET="SMOKE"
export TESTSET

# Set the defaults for connecting to the VM
ip="$LIVEHOST"
fuser="$LIVEUSER"
fpass="$LIVEPASS"

while [ $# -gt 0 ] ; do
  # Parse the CLI args
  key=`echo $1 | cut -d '=' -f 1`
  val=`echo $1 | cut -d '=' -f 2`

  case "$key" in
    testset|TESTSET) case "$val" in
      SMOKE|smoke) export TESTSET="SMOKE" ;;
        COMPLETE|complete) export TESTSET="COMPLETE" ;;
    BENCHMARK|benchmark) export TESTSET="BENCHMARK" ;;
      *) ;;
                     esac
                     ;; 
     module|MODULE) runmod="$val $runmod" ;;
     ip|IP) ip="$val" ; manualip="YES" ;;
     user|USER) fuser="$val" ;;
     pass|PASS) fpass="$val" ;;
    *) ;;
  esac
  shift
done

echo "Using REST API Address: ${ip}"

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

clean_xml_results

start_xml_results

# When running via Jenkins / ATF mode, it may take a variable
# time to boot the system and be ready for REST calls. We run
# an initial test to determine when the interface is up
set_test_group_text "Testing Connectivity" "1"
echo_test_title "Testing access to REST API"
wait_for_avail
echo_ok

RESULT="SUCCESS"

if [ -n "$runmod" ] ; then
  for mod in $runmod
  do
    # Run a specific module
    run_module "$mod"
    if [ $? -ne 0 ] ; then
      RESULT="FAILURE"
    fi
  done
else
  # Now start going through our test modules
  read_module_dir
  if [ $? -ne 0 ] ; then
    RESULT="FAILURE"
  fi
fi

# Made it to the end, exit with success!
echo "$RESULT - $TOTALCOUNT tests run - REST API testing complete!"

finish_xml_results "$TOTALCOUNT"

exit 0
