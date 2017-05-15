#!/bin/sh

# Where is the build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/trueos.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

create_dist_files() {

  # Create the FreeBSD Dist Files
  if [ -n "${DISTDIR}" -a -d "${DISTDIR}" ] ; then
    rm -rf ${DISTDIR}
  fi
  mkdir ${DISTDIR} 2>/dev/null

 # cd to release dir, and clean and make
  cd ${WORLDSRC}/release
  make clean ${SYS_MAKEFLAGS}

  # Create the FTP files
  make ftp NOPORTS=yes ${SYS_MAKEFLAGS}
  if [ $? -ne 0 ] ; then
     echo "Failed running: make ftp NOPORTS=yes ${SYS_MAKEFLAGS}"
     exit 1
  fi
  rc_halt "mv ${WORLDSRC}/release/ftp/* ${DISTDIR}/"

  # Cleanup old .txz files
  cd ${WORLDSRC}/release
  make clean ${SYS_MAKEFLAGS}

  return 0
}

create_base_pkg_files()
{
  cd ${WORLDSRC}

  if [ -n "${PROGDIR}/fbsd-pkg" -a -d "${PROGDIR}/fbsd-pkg" ] ; then
    rm -rf ${PROGDIR}/fbsd-pkg
  fi
  mkdir ${PROGDIR}/fbsd-pkg 2>/dev/null

  # Unset some variables which may be getting in the way
  ODISTDIR="$DISTDIR"
  OWORLDSRC="$WORLDSRC"
  unset DISTDIR WORLDSRC

  # Create the package files now
  make packages ${SYS_MAKEFLAGS}
  if [ $? -ne 0 ] ; then
     env
     echo "Failed running: make packages ${SYS_MAKEFLAGS}"
     exit 1
  fi

  # Move the package files and prep them
  mv /usr/obj/usr/src/repo/*/latest/* ${PROGDIR}/fbsd-pkg/
  if [ $? -ne 0 ] ; then
     echo "Failed moving packages"
     exit 1
  fi

  # This is super ugly, remove it once they properly fix pkg
  # grab all the distrib files
  rc_halt "mkdir ${PROGDIR}/fbsd-distrib"
  cd /usr/src
  make distrib-dirs DESTDIR=${PROGDIR}/fbsd-distrib ${SYS_MAKEFLAGS}
  if [ $? -ne 0 ] ; then
     env
     echo "Failed running: make distrib-dirs ${SYS_MAKEFLAGS}"
     exit 1
  fi
  make distribution DESTDIR=${PROGDIR}/fbsd-distrib ${SYS_MAKEFLAGS}
  if [ $? -ne 0 ] ; then
     env
     echo "Failed running: make distribution ${SYS_MAKEFLAGS}"
     exit 1
  fi

  # Couple of files also missed by pkg base
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/lib/libgcc_eh.a ./usr/lib/libgcc_eh_p.a"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/share/examples"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/share/calendar"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/share/tmac"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/include"

  # Signing script
  if [ -n "$PKGSIGNCMD" ] ; then
    echo "Signing base packages..."
    rc_halt "cd ${PROGDIR}/fbsd-pkg/"
    rc_halt "pkg repo . signing_command: ${PKGSIGNCMD}"
  fi

  rc_halt "tar cvJf ${PROGDIR}/fbsd-pkg/fbsd-distrib.txz -C ${PROGDIR}/fbsd-distrib ."
  rc_halt "openssl dgst -sha1 -sign /etc/ssl/pcbsd-pkgng.key -out ${PROGDIR}/fbsd-pkg/fbsd-distrib.txz.sha1 ${PROGDIR}/fbsd-pkg/fbsd-distrib.txz"
  rm -rf ${PROGDIR}/fbsd-distrib

  WORLDSRC="$OWORLDSRC"
  DISTDIR="$ODISTDIR"
  return 0
}

# Create a static tarball
create_tarball() {

  if [ -n "${DISTDIR}" -a -d "${DISTDIR}" ] ; then
    rm -rf ${DISTDIR}
  fi
  mkdir ${DISTDIR} 2>/dev/null

  rc_halt "mkdir ${PROGDIR}/fbsd-distrib"
  make installworld DESTDIR=${PROGDIR}/fbsd-distrib ${SYS_MAKEFLAGS}
  if [ $? -ne 0 ] ; then
     echo "Failed running: make installworld ${SYS_MAKEFLAGS}"
     exit 1
  fi

  make distribution DESTDIR=${PROGDIR}/fbsd-distrib ${SYS_MAKEFLAGS}
  if [ $? -ne 0 ] ; then
     echo "Failed running: make distribution ${SYS_MAKEFLAGS}"
     exit 1
  fi

  make installkernel DESTDIR=${PROGDIR}/fbsd-distrib ${SYS_MAKEFLAGS}
  if [ $? -ne 0 ] ; then
     echo "Failed running: make installkernel ${SYS_MAKEFLAGS}"
     exit 1
  fi

  # Create the tarball
  rc_halt "tar cvJf ${DISTDIR}/fbsd-dist.txz -C ${PROGDIR}/fbsd-distrib ."
  rm -rf ${PROGDIR}/fbsd-distrib
  chflags -R noschg ${PROGDIR}/fbsd-distrib 2>/dev/null
  rm -rf ${PROGDIR}/fbsd-distrib 2>/dev/null

  return 0
}

if [ -z "$DISTDIR" ] ; then
  DISTDIR="${PROGDIR}/fbsd-dist"
fi

# Ugly, but freebsd packages like to be built here for now
if [ -n "$PKGBASE" ] ; then
  WORLDSRC="/usr/src"
  rm -rf /usr/obj/usr/src/repo/ >/dev/null 2>/dev/null
fi

# Make sure we have our freebsd sources
if [ -d "${WORLDSRC}" ]; then 
  rm -rf ${WORLDSRC}
  chflags -R noschg ${WORLDSRC} >/dev/null 2>/dev/null
  rm -rf ${WORLDSRC} >/dev/null 2>/dev/null
fi
mkdir -p ${WORLDSRC}
rc_halt "git clone --depth=1 -b ${GITFBSDBRANCH} ${GITFBSDURL} ${WORLDSRC}"

# Now create the world / kernel / distribution
cd ${WORLDSRC}

CPUS=`sysctl -n kern.smp.cpus`

if [ "$BUILDTAG" = "trueos-ino64" ] ; then
	# Special build instructions
	echo "Doing ino64 setup..."
	cd ${WORLDSRC}
	cd sys/kern && touch syscalls.master && make sysent
	cd ${WORLDSRC}
	cd sys/compat/freebsd32 && touch syscalls.master && make sysent
	cd ${WORLDSRC}
fi

make -j $CPUS buildworld buildkernel ${SYS_MAKEFLAGS}
if [ $? -ne 0 ] ; then
   echo "Failed running: make buildworld buildkernel ${SYS_MAKEFLAGS}"
   exit 1 
fi

if [ -z "$BUILDTYPE" ] ; then
   BUILDTYPE="amd64"
fi

echo "Packaging as: $BUILDTYPE"
case ${BUILDTYPE} in
  PICO) create_tarball && exit $? ;;
     *) create_dist_files
        if [ -n "$PKGBASE" ] ; then
          create_base_pkg_files
        fi
        ;;
esac

exit 0
