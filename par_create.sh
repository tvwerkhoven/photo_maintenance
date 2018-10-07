#!/usr/bin/env bash
# 
# # Usage
#   ./par_create.sh <check_dir> [par_dir]
#
# # About 
# Create par2 files to protect (picture) archives against bitrot. Use this 
# wrapper to check some stuff before parchiving.
# 
# - Wrap par2 in nice to prevent system load
# - Wrap par2 in caffeinate to stay awake
# - Use default redundancy, good compromise between speed and size
#
# # Par2 overhead
# 
# - Time scales ±linearly with number of recovery blocks and input file size
# - Disk use scales with linearly with block count and slowly with redundancy 
#   percentage
# - Block count cannot be smaller than the number of files.
# - Par2 speed is linear with archive size (i.e. 1 par on 10GB archive is same
#   speed as 10x par on separate archives)
#
# # Par2 performance test
#
# for 167 MB archive
# default:     9.5 MB.  = 5.6% @ 9.576 (100 rec blocks) -- faster
# -R1 -b10000: 7.18 MB. = 5%   @ 9.1s  (100 rec blocks)
# -R1 -b20000: 15.6 MB. = 9%   @ 17.7s (200 rec blocks)
# -R1 -b30000: 7.8*3 MB = 14%  @ 26.6s (300)
# -R2 -b10000: 10.3 MB  = 6%   @ 17s   (200 rec blocks) -- optimal
# -c200        18.33 MB = 11%  @ 17.2s (200 rec blocks)
# -b30000 -c100: 16.7MB = 10%  @ 9.1s  (100 rec blocks)
# 
# For 349 MB archive
# default: 18.6 MB      = 5.3% @ 18.8s (100 rec blocks) 
# 
# For 1050 MB archive
# default: 54.1 MB      = 5.1% @ 56.3s (100 rec blocks) 
#
# TODO
# 
# count number of files
# set # blocks equal to # of files (or double? or +1?)
# set 100 rec blocks

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

if [[ -c ${PAR_FILE} ]]; then echo "par2 already exists, aborting"; cd ${CURDIR}; exit; fi

# Count number of files so we know how many blocks to use. Use tr to trim 
# whitespace (https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable)
NUM_FILES=$(find . | wc -l | tr -d '[:space:]')

# Once in the right dir, start par2 through nice and caffeinate to not disturb stuff and stay awake
nice -n 10 ${PROG_CAFFEINATE} -ms ${PROG_PAR2} c -b${NUM_FILES} -c100 -R ${PAR_FILE} ./* | tee -a ${PAR_LOG_FILE}

# # Caffeinate 
#     -m: prevent disk from sleeping
#     -s: prevent the system from sleeping
# # par2 
#     c: create
#     -R: recursive
# not used now:
#     -r1: 1% redundancy (which suffices since we expect bitflips only)
#     -b100000: make many blocks (10k) such that we can take many bitflip hits

# cd back to original dir
cd ${CURDIR}


# Future: can use parallels to speed up creation
# function create_par {
#   CURDIR=$(pwd)
#   CHECKDIR=$1
#   #PHOTODIR=/Users/tim/Pictures/

#   parcmd=/Users/tim/Pictures/maintenance/par2  
#   parlogf=/Users/tim/Pictures/maintenance/creating.par2.log
#   parfile=${CHECKDIR}0000.par2
  
#   cd ${CHECKDIR}

#   # Remove DS_Store files, these are not important and change often, polluting
#   # the PAR2 archive
#   # find ${CHECKDIR} -type f | grep .DS_Store$ | xargs rm

#   # Move existing PAR files to archive dir
#   mv *par2 ${PHOTODIR}/maintenance/0-oldpar/

#   date
#   echo "Now creating PAR in $(pwd)\n========================="
#   nice -n 10 caffeinate -ms ${parcmd} c -R -r1 -b10000 ${parfile} ./*

#   cd ${CURDIR}
# }

# create_par 2016* | tee -a ${parlogf}

# Using parallel:

# parlogf=/Users/tim/Pictures/maintenance/creating.par2.log
# rm -f ${parlogf}
# export -f create_par

# parallel -j 4 -k create_par ::: {2000,2002}* | tee -a ${parlogf}
# parallel -j 4 -k create_par ::: {2015,2010,2009,2008,2007,2006,2005,2003}* | tee -a ${parlogf}
# parallel -j 4 -k create_par ::: {0,1,20}* | tee -a ${parlogf}
# parallel -j 4 -k create_par ::: {200,201}* | tee -a ${parlogf}
