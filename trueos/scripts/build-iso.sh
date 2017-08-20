#!/bin/sh
# PC-BSD Build configuration settings

# Where is the build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Copy .dist files if necessary
if [ ! -e "${PROGDIR}/trueos.cfg" ] ; then
   cp ${PROGDIR}/trueos.cfg.dist ${PROGDIR}/trueos.cfg
fi
if [ ! -e "${PROGDIR}/repo.conf" ] ; then
   cp ${PROGDIR}/repo.conf.dist ${PROGDIR}/repo.conf
fi
if [ ! -d "${PROGDIR}/pkg" ] ; then
   cp -r ${PROGDIR}/pkg-dist ${PROGDIR}/pkg
fi
if [ ! -d "${PROGDIR}/pbi" ] ; then
   cp -r ${PROGDIR}/pbi-dist ${PROGDIR}/pbi
fi

cd ${PROGDIR}/scripts

# Source the config file
. ${PROGDIR}/trueos.cfg

# First, lets check if we have all the required programs to build an ISO
. ${PROGDIR}/scripts/functions.sh

# Check if we have required programs
sh ${PROGDIR}/scripts/checkprogs.sh
cStat=$?
if [ $cStat -ne 0 ] ; then exit $cStat; fi

do_world() {

  echo "Starting build of FreeBSD/TrueOS"
  ${PROGDIR}/scripts/1.createworld.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_iso() 
{
  if [ "$ARCH" = "i386" ] ; then return 0; fi

  echo "Building ISO file"

  rm ${PROGDIR}/iso/* >/dev/null 2>/dev/null

  # If on ARM, only need single image
  echo "$PACKAGE_ARCH" | grep -q "arm"
  if [ $? -eq 0 ] ; then
    unset SYSBUILD
  fi
  
   # If on AMD64, only need single image
  if [ -z "$PACKAGE_ARCH" -o "$PACKAGE_ARCH" = "amd64" ] ; then
    SYSBUILD="both"
  fi

  # Are we building both TrueOS / PC-BSD images?
  if [ -z "$SYSBUILD" -o "$SYSBUILD" = "BOTH" ] ; then

    local oSys="$SYSBUILD"
    DOINGSYSBOTH="YES" ; export DOINGSYSBOTH
    SYSBUILD="desktop" ; export SYSBUILD
    ${PROGDIR}/scripts/9.freesbie.sh
    if [ $? -ne 0 ] ; then
      echo "Script failed!"
      exit 1
    fi
    SYSBUILD="server" ; export SYSBUILD
    ${PROGDIR}/scripts/9.freesbie.sh
    if [ $? -ne 0 ] ; then
      echo "Script failed!"
      exit 1
    fi
    SYSBUILD="$oSys" ; export SYSBUILD
    unset DOINGSYSBOTH
  else
    ${PROGDIR}/scripts/9.freesbie.sh
    if [ $? -ne 0 ] ; then
      echo "Script failed!"
      exit 1
    fi
  fi

  # Make the net install file directory now
  echo "Making Net Files"
  ${PROGDIR}/scripts/9.6.makenetfiles.sh
  if [ $? -ne 0 ] ; then
     exit_err "Failed running 9.6.makenetfiles.sh"
  fi

}

do_vms() {
  echo "Creating VM images"
  ${PROGDIR}/scripts/9.7.makevbox.sh
  if [ $? -ne 0 ] ; then
     exit_err "Failed running 9.7.makevbox.sh"
  fi
}

do_clean()
{
  rm ${PROGDIR}/tmp/* 2>/dev/null
  rm ${PROGDIR}/tmp/All/* 2>/dev/null
}

do_iso_ports()
{
  echo "Building ISO ports"

  if [ ! -e "${DISTDIR}/base.txz" -a ! -e "${DISTDIR}/fbsd-dist.txz" ] ; then
     echo "Missing WORLD files, please create first!"
     exit 1
  fi

  sh ${PROGDIR}/scripts/portbuild.sh iso
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_ports()
{
  echo "Building RELEASE ports"

  if [ ! -e "${DISTDIR}/base.txz" ] ; then
     echo "Missing WORLD files, please create first!"
     exit 1
  fi

  sh ${PROGDIR}/scripts/portbuild.sh all
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_ports_all()
{
  sh ${PROGDIR}/scripts/portbuild.sh portsnap
  exit $?
}

do_pbi-index()
{
  if [ "$ARCH" = "i386" ] ; then return 0; fi
  sh ${PROGDIR}/scripts/portbuild.sh pbi-index
  exit $?
}

do_ports_trueos()
{
  if [ ! -d "${PJPORTSDIR}" ] ; then
     sh ${PROGDIR}/scripts/portbuild.sh portsnap
     if [ $? -ne 0 ] ; then
        exit 1
     fi
  fi
  sh ${PROGDIR}/scripts/portbuild.sh portmerge
  exit $?
}

do_check_ports()
{
  if [ "$ARCH" = "i386" ] ; then return 0; fi
  check_essential_pkgs "NO"
  exit $?
}

echo "Operation started: `date`"

TARGET="$1"
if [ -z "$TARGET" ] ; then TARGET="all"; fi

case $TARGET in
 all|ALL) do_world 
	  do_ports
	  if [ $? -ne 0 ] ; then exit 1 ; fi
          do_iso ;;
   world) do_world ;;
     iso) do_iso ;;
      vm) do_vms ;;
   ports) do_ports; exit $? ;;
iso-ports) do_iso_ports; exit $? ;;
check-ports) do_check_ports ;;
ports-update-all) do_ports_all ;;
ports-update-trueos) do_ports_trueos ;;
pbi-index) do_pbi-index ;;
   clean) do_clean ;;
    menu) sh ${PROGDIR}/scripts/menu.sh ;;
       *) ;;
esac


echo "Operation finished: `date`"
exit 0
