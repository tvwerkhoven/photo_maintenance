#!/usr/bin/env bash
# 
# # Usage
#   ./par_check.sh <check_dir>

if [[ $1 = "-h" ]] || [[ $1 = "--help" ]] || [[ $# -lt 1 ]]; then
  echo "Usage: $(basename $0) <check_dir>"
  exit
fi

PROG_PAR2=/usr/local/bin/par2
PROG_CAFFEINATE=/usr/bin/caffeinate
# Convert relative path to absolute, if $1 does not exist, cd fails and 
# CHECK_DIR is empty
CHECK_DIR=$(cd $1 && pwd)
# Check if directory exists
if [[ ! -d ${CHECK_DIR} ]]; then echo "dir to check \"${CHECK_DIR}\" does not exist, aborting"; exit; fi

# Check if tools exist
HAVE_TOOLS=1
if [[ ! -x ${PROG_PAR2} ]]; then echo "par2 not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_CAFFEINATE} ]]; then echo "caffeinate not found"; HAVE_TOOLS=0; fi

if [[ ${HAVE_TOOLS} -eq 0 ]]; then echo "Not all tools available, aborting"; exit; fi


# Store current working dir, then cd to par dir such that ourput par2 files will be in correct directory
CURDIR=$(pwd)
cd ${CHECK_DIR}
CHECK_DIR_BASE=$(basename $(pwd))
# Check if this dir already has PAR files
PAR_FILE=${CHECK_DIR_BASE}0000.par2
PAR_LOG_FILE=${CHECK_DIR_BASE}0000.par2.log

if [[ ! -f ${PAR_FILE} ]]; then echo "par2 file does not exist, aborting"; cd ${CURDIR}; exit; fi

# Once in the right dir, start par2 through nice and caffeinate to not disturb stuff and stay awake
nice -n 10 ${PROG_CAFFEINATE} -ms ${PROG_PAR2} v ${PAR_FILE} | tee -a ${PAR_LOG_FILE}


#### old

# PROG_PAR2=/Users/tim/Pictures/maintenance/par2cmdline-0.6.13/par2
# parlogf=/Users/tim/Pictures/maintenance/checking.par2.log


# function check_par {
#   CHECKDIR=$1
#   CURDIR=$(pwd)
#   PHOTODIR=/Users/tim/Pictures/

#   parcmd=/Users/tim/Pictures/maintenance/par2  
#   parlogf=/Users/tim/Pictures/maintenance/checking.par2.log
#   parfile=${CHECKDIR}0000.par2
  
#   cd ${PHOTODIR}/${CHECKDIR}
#   date
#   echo "Now checking $(pwd)\n========================="
#   nice -n 5 caffeinate -ms ${parcmd} v ${parfile} | grep -v "Target.* - found.$|^Load|^Scanning: "
#   cd ${CURDIR}
# }

# parlogf=/Users/tim/Pictures/maintenance/checking.par2.log
# rm -f ${parlogf}

# # single threaded

# #for PICDIR in *{00,02}; do
# for PICDIR in *2016; do
# for PICDIR in {0,1,2}*; do
# 	echo $PICDIR
# 	check_par $PICDIR
# done

# # Using parallel:

# export -f check_par
# parallel -j 4 -k check_par ::: {0,1,2}* | tee -a ${parlogf}

# # Check files with potential errors

# mkdir /Users/tim/Pictures/maintenance/checkpar

# for chkf in $(grep ^File: $parlogf | cut -f2 -d\"); do
#   yr=$chkf[0,4]
#   #newf=$(echo $chkf | cut -f1 -d'/')$(echo $chkf | cut -f2 -d'/')
#   newf=${chkf/\//}
#   ln -s /Users/tim/Pictures/${yr}/${chkf} /Users/tim/Pictures/maintenance/checkpar/${newf}
# done
