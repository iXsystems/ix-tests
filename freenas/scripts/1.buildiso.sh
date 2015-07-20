#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/freenas.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Make sure we have our freenas sources
if [ ! -d "${FNASSRC}" ]; then 
   rc_nohalt "rm -rf /tmp/fnasb"
   rc_nohalt "chflags -R noschg /tmp/fnasb"
   rc_nohalt "rm -rf /tmp/fnasb"
   rc_nohalt "mkdir `dirname ${FNASSRC}`"
   rc_halt "git clone --depth=1 ${GITFNASURL} /tmp/fnasb"
   rc_halt "ln -s /tmp/fnasb ${FNASSRC}"
   git_fnas_up "${FNASSRC}" "${FNASSRC}"
else
  if [ -d "${GITBRANCH}/.git" ]; then 
    echo "Updating FreeNAS sources..."
    git_fnas_up "${FNASSRC}" "${FNASSRC}"
  fi
fi

# Now create the world / kernel / distribution
cd ${FNASSRC}

# Ugly hack to get freenas 9.x to build on CURRENT
if [ -n "$FREENASLEGACY" ] ; then

   # Legacy FreeNAS 9.3
   rc_halt "make checkout"

   # Add all the fixes to use a 9.3 version of mtree
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/Makefile.inc1
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/release/Makefile.sysinstall
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/release/picobsd/build/picobsd
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/tools/tools/tinybsd/tinybsd
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/share/examples/Makefile
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/include/Makefile
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/usr.sbin/sysinstall/install.c
   MTREE_CMD="${PROGDIR}/scripts/kludges/mtree"
   export MTREE_CMD

   if [ ! -e "/usr/bin/makeinfo" ] ; then
      cp ${PROGDIR}/scripts/kludges/makeinfo /usr/bin/makeinfo
      chmod 755 /usr/bin/makeinfo
   fi
   if [ ! -e "/usr/bin/install-info" ] ; then
      cp ${PROGDIR}/scripts/kludges/install-info /usr/bin/install-info
      chmod 755 /usr/bin/install-info
   fi

   # Copy our kludged build_jail.sh
   cp ${PROGDIR}/scripts/kludges/build_jail.sh ${FNASSRC}/build/build_jail.sh

   # NANO_WORLDDIR expects this to exist
   if [ ! -d "/var/home" ] ; then
      mkdir /var/home
   fi

   # Fix a missing directory in NANO_WORLDDIR
   sed -i '' 's|geom_gate.ko|geom_gate.ko;mkdir -p ${NANO_WORLDDIR}/usr/src/sys|g' ${FNASSRC}/_BE/freenas/build/nanobsd-cfg/os-base-functions.sh

   # Do the build now
   rc_halt "make release"
else
   # FreeNAS 9.3 + FreeBSD 10.2 base OS
   rc_halt "make checkout PROFILE=freenas9"
   # Do the build now
   rc_halt "make release PROFILE=freenas9"
fi

