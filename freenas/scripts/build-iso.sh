#!/usr/bin/env sh
# FreeNAS Build configuration settings

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Copy .dist files if necessary
if [ ! -e "${PROGDIR}/freenas.cfg" ] ; then
   cp ${PROGDIR}/freenas.cfg.dist ${PROGDIR}/freenas.cfg
fi

cd ${PROGDIR}/scripts

# Source the config file
. ${PROGDIR}/freenas.cfg

# First, lets check if we have all the required programs to build an ISO
. ${PROGDIR}/scripts/functions.sh

# Check if we have required programs
# echo "*** Prepping Jenkins Node ***"
# sh ${PROGDIR}/scripts/checkprogs.sh 2>&1 >/var/tmp/.cProgs.$$
# cStat=$?
# if [ $cStat -ne 0 ] ; then
#   cat /var/tmp/.cProgs.$$
#   rm /var/tmp/.cProgs.$$
#  exit $cStat
# fi
# rm /var/tmp/.cProgs.$$

do_iso() {

  echo "Starting build of FreeNAS"
  ${PROGDIR}/scripts/1.buildiso.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_doc() {

  echo "Starting build of FreeNAS handbook"
  ${PROGDIR}/scripts/1.buildiso.sh docs
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_api() {

  echo "Starting build of FreeNAS API handbook"
  ${PROGDIR}/scripts/1.buildiso.sh api-docs
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}


do_live_tests() {

  echo "Starting FreeNAS Live regression testing"
  ${PROGDIR}/scripts/3.runlivetests.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_live_upgrade() {

  echo "Starting FreeNAS Live upgrade testing"
  ${PROGDIR}/scripts/3.runliveupgrade.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}


do_tests() {

  echo "Starting FreeNAS regression testing"
  ${PROGDIR}/scripts/2.runtests.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

echo "Operation started: `date`"

TARGET="$1"
if [ -z "$TARGET" ] ; then TARGET="all"; fi

case $TARGET in
     all) do_iso ; do_tests ;;
     iso) do_iso ;;
    doc) do_doc ;;
     api) do_api ;;
   tests) do_tests ;;
   livetests) do_live_tests ;;
   liveupgrade) do_live_upgrade ;;
       *) ;;
esac


echo "Operation finished: `date`"
exit 0
