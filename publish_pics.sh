#!/usr/bin/env bash
#
# # About
#_convert_pics
# Publish selected pictures and videos for web-sharing (i.e. smaller), which
# can subsequently be copied to iPhone so one can store more pics on a phone
#
#
#
# # Sources
#
# Based on 
# Bash Boilerplate: https://github.com/alphabetum/bash-boilerplate
# Copyright (c) 2015 William Melody • hi@williammelody.com

# set -xv
###############################################################################
# Strict Mode
###############################################################################
set -o nounset

# Exit immediately if a pipeline returns non-zero.
set -o errexit

# Print a helpful message if a pipeline with non-zero exit code causes the
# script to exit as described above.
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR

# Allow the above trap be inherited by all functions in the script.
set -o errtrace

# Return value of a pipeline is the value of the last (rightmost) command to
# exit with a non-zero status, or zero if all commands in the pipeline exit
# successfully.
set -o pipefail

# Set $IFS to newline, tab, and space (was only \n\t)
IFS=$'\n\t '

###############################################################################
# Environment
###############################################################################

# $_ME
#
# Set to the program's basename.
_ME=$(basename "${0}")

###############################################################################
# Debug
###############################################################################

# _debug()
#
# Usage:
#   _debug printf "Debug info. Variable: %s\n" "$0"
#
# A simple function for executing a specified command if the `$_USE_DEBUG`
# variable has been set. The command is expected to print a message and
# should typically be either `echo`, `printf`, or `cat`.
__DEBUG_COUNTER=0
_debug() {
  if [[ "${_USE_DEBUG:-"0"}" -eq 1 ]]
  then
    __DEBUG_COUNTER=$((__DEBUG_COUNTER+1))
    # Prefix debug message with "bug (U+1F41B)"
    printf "🐛  %s " "${__DEBUG_COUNTER}"
    "${@}"
    printf "――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――\\n"
  fi
}
# debug()
#
# Usage:
#   debug "Debug info. Variable: $0"
#
# Print the specified message if the `$_USE_DEBUG` variable has been set.
#
# This is a shortcut for the _debug() function that simply echos the message.
debug() {
  _debug echo "${@}"
}

###############################################################################
# Die
###############################################################################

# _die()
#
# Usage:
#   _die printf "Error message. Variable: %s\n" "$0"
#
# A simple function for exiting with an error after executing the specified
# command. The command is expected to print a message and should typically
# be either `echo`, `printf`, or `cat`.
_die() {
  # Prefix die message with "cross mark (U+274C)", often displayed as a red x.
  printf "❌  "
  "${@}" 1>&2
  exit 1
}
# die()
#
# Usage:
#   die "Error message. Variable: $0"
#
# Exit with an error and print the specified message.
#
# This is a shortcut for the _die() function that simply echos the message.
die() {
  _die echo "${@}"
}

###############################################################################
# Help
###############################################################################

# _print_help()
#
# Usage:
#   _print_help
#
# Print the program help information.
_print_help() {
  cat <<HEREDOC

publish_pics

Publish selected pictures and videos for web-sharing (i.e. smaller), which
can subsequently be copied to iPhone so one can store more pics on a phone

Usage:
  ${_ME} [--options] <export_root>
  ${_ME} -h | --help --debug --no-vids --no-pics --dry-run -s | --sourcedir

Options:
  -h --help  Display this help information.
  --debug    Print extra processing info.
  --dry-run  Only check which files would be copied, do not convert/copy.
  --no-vids  Do not process videos
  --no-pics  Do not process pictures
  -s --sourcedir Directory to read from, defaults to current dir.
  <export_root> Directory to create output directory and files in.
HEREDOC
}

###############################################################################
# Touch file ref
###############################################################################

# _touch_file_ref()
#
# Usage:
#   _touch_file_ref <ref> <target>
#
# Set creation & modification datetime of <target> file to <ref>
_touch_file_ref() {
  if [[ ! -f "${1}" || ! -f "${2}" ]]; then
    die "Error: file ${1} or ${2} does not exist, should not happen"
  else
    # Fix timestamp (only file, metadata is OK)
    ${_PROG_TOUCH} -r "${1}" "${2}"
    # Use setfile to set creation time
    # https://apple.stackexchange.com/questions/99536/changing-creation-date-of-a-file
    ${_PROG_SETFILE} -d "$(${_PROG_GETFILEINFO} -d "${1}")" "${2}"
  fi
}

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0
_CONV_PICS=1
_CONV_VIDS=1
_DRY_RUN=0
# Initialize additional expected option variables.
_EXPORT_ROOT=
_SOURCE_DIR="."

_GPX_FMT_PATH="/tmp/gpx.fmt"
_MOOV_META_PATH="/tmp/moov-meta-atom.bin"

_PROG_EXIFTOOL=/opt/local/bin/exiftool
# http://mywiki.wooledge.org/BashFAQ/050#I.27m_constructing_a_command_based_on_information_that_is_only_known_at_run_time
_PROG_EXIFTOOL_OPTS=(-quiet -quiet -ignoreMinorErrors)
_PROG_FILE=/usr/bin/file
_PROG_CONVERT=/opt/local/bin/convert
_PROG_TOUCH=/usr/bin/touch
_PROG_SETFILE=/usr/bin/SetFile
_PROG_GETFILEINFO=/usr/bin/GetFileInfo
_PROG_STAT=/opt/local/bin/gstat
_PROG_FFMPEG=/opt/local/bin/ffmpeg
_PROG_NICE=/usr/bin/nice
_PROG_CUT=/usr/bin/cut
_PROG_DATE=/opt/local/bin/gdate
_PROG_MP4EXTRACT=/usr/local/bin/mp4extract
_PROG_MP4EDIT=/usr/local/bin/mp4edit

# _require_argument()
#
# Usage:
#   _require_argument <option> <argument>
#
# If <argument> is blank or another option, print an error message and  exit
# with status 1.
_require_argument() {
  # Set local variables from arguments.
  #
  # NOTE: 'local' is a non-POSIX bash feature and keeps the variable local to
  # the block of code, as defined by curly braces. It's easiest to just think
  # of them as local to a function.
  local _option="${1:-}"
  local _argument="${2:-}"

  if [[ -z "${_argument}" ]] || [[ "${_argument}" =~ ^- ]]
  then
    _die printf "Option requires an argument: %s\\n" "${_option}"
  fi
}

while [[ ${#} -gt 0 ]]
do
  __option="${1:-}"
  __maybe_param="${2:-}"
  case "${__option}" in
    -h|--help)
      _PRINT_HELP=1
      ;;
    --debug)
      _USE_DEBUG=1
      ;;
    --dry-run)
      _DRY_RUN=1
      ;;
    --no-vids)
      _CONV_VIDS=0
      ;;
    --no-pics)
      _CONV_PICS=0
      ;;
    -s)
      _require_argument "${__option}" "${__maybe_param}"
      _SOURCE_DIR="${__maybe_param}"
       shift
      ;;
    --sourcedir)
      _require_argument "${__option}" "${__maybe_param}"
      _SOURCE_DIR="${__maybe_param}"
      shift
      ;;
    --endopts)
      # Terminate option parsing.
      break
      ;;
    -*)
      _die printf "Unexpected option: %s\\n" "${__option}"
      ;;
    *)
      # Use any final argument as target export dir
      _EXPORT_ROOT="${__option}"
      ;;
  esac
  shift
done


###############################################################################
# Program Functions
###############################################################################

_check_prereq() {
  _debug printf "_check_prereq()" 
  if [[ -z "${_EXPORT_ROOT}" ]]; then 
    _print_help
    exit
  fi

  # Check if source an export dir exists
  if [[ ! -d "${_EXPORT_ROOT}" ]]; then 
    _die printf "Error: export dir \"%s\" does not exist, aborting\\n" "${_EXPORT_ROOT}";
  elif [[ ! -d "${_SOURCE_DIR}" ]]; then 
    _die printf "Error: source dir \"%s\" does not exist, aborting\\n" "${_SOURCE_DIR}";
  fi
  
  # Check if tools exist
  local _have_tools=1
  if [[ ! -x "${_PROG_EXIFTOOL}" ]]; then echo "exiftool not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_FILE}" ]]; then echo "file not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_CONVERT}" ]]; then echo "convert not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_TOUCH}" ]]; then echo "touch not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_STAT}" ]]; then echo "(g)stat not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_FFMPEG}" ]]; then echo "ffmpeg not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_NICE}" ]]; then echo "nice not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_CUT}" ]]; then echo "cut not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_DATE}" ]]; then echo "(g)date not found"; _have_tools=0; fi
  if [[ ! -x "${_PROG_MP4EXTRACT}" ]]; then echo "mp4extract not found - get from https://www.bento4.com/"; _have_tools=0; fi
  if [[ ! -x "${_PROG_MP4EDIT}" ]]; then echo "mp4edit not found - get from https://www.bento4.com/"; _have_tools=0; fi
  
  if [[ $(uname) == "Darwin" ]]; then
    # If on Mac, we need SetFile/GetFile to fix creation date/time
    if [[ ! -x "${_PROG_SETFILE}" ]]; then echo "SetFile not found"; _have_tools=0; fi
    if [[ ! -x "${_PROG_GETFILEINFO}" ]]; then echo "GetFileInfo not found"; _have_tools=0; fi
  else
    # If not on Mac, set these progs to a noop command (untested)
    _PROG_SETFILE=true
    _PROG_GETFILEINFO=true
  fi

  if [[ ${_have_tools} -eq 0 ]]; then
    _die printf "Error: required tools missing, aborting\\n";
  fi

  # Check if we have any files with rating. Always quiet to prevent other output

  # Set case insensitive glob and nullglob (such that lack of file hit will 
  # give null back instead of the glob string)
  shopt -s nocaseglob
  shopt -s nullglob

  local _havematches
  _havematches=$(${_PROG_EXIFTOOL} -q -q -ignoreMinorErrors -rating "${_SOURCE_DIR}"/*{avi,mov,mp4,png,jpg} || true)
  if [[ -z "${_havematches}" ]]; then
    _die printf "No matches for this directory\n"
  fi
  shopt -u nocaseglob
  shopt -u nullglob
}

_prep_input() {
  _debug printf "_prep_input()" 
  # First set file date to creation date from metadata, movies and images 
  # separately so we can chose what to convert. Use -wm w to not create new 
  # tags
  # See: https://photo.stackexchange.com/questions/83657/any-program-to-change-date-created-of-videos-to-actual-exif-data
  # Not sure which works reliably for videos
  # See: https://exiftool.org/forum/index.php?topic=6318.msg33921#msg33921

  # Set case insensitive glob and nullglob (such that lack of file hit will 
  # give null back instead of the glob string)
  shopt -s nocaseglob
  shopt -s nullglob

  if [[ "${_CONV_VIDS:-"0"}" -eq 1 && "${_DRY_RUN:-"0"}" -eq 0 ]]; then
    # We use CreateDate as leading date for videos. Add || true in case 
    # exiftool finds no matches (and returns 2)
    _debug printf "Preparing timestamps on movies"
    # https://photo.stackexchange.com/questions/69959/when-is-each-of-these-exif-date-time-variables-created-and-in-what-circumstan
    ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" "-CreateDate>FileModifyDate" "-DateTimeOriginal>FileModifyDate" -P -wm w "${_SOURCE_DIR}"/*{avi,mov,mp4} || true
  fi
  if [[ "${_CONV_PICS:-"0"}" -eq 1 && "${_DRY_RUN:-"0"}" -eq 0 ]]; then
    _debug printf "Preparing timestamps on pictures"
    # We use DateTimeOriginal as leading date for pictures. Add || true in case 
    # exiftool finds no matches (and returns 2)
    ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" "-DateTimeOriginal>FileModifyDate" -P -wm w "${_SOURCE_DIR}"/*{png,jpg} || true
  fi

  # @TODO this code is extremely slow. Can we rely on errors from exiftool when setting filemodifydate and source tag does not exist?
  # If no exif timestamps, check and decide what to do.
  # local _nodatetimeoriginal
  # _nodatetimeoriginal=$(${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '($rating and not ($datetimeoriginal or $CreateDate))' -p '$filename' ${_SOURCE_DIR}/*{png,jpg,avi,mov,mp4} || true)
  # if [[ -n "${_nodatetimeoriginal}" ]]; then
  #   printf "Warning: %d files have no DateTimeOriginal or CreateDate:\n%s\nok to continue?" "$(echo "${_nodatetimeoriginal}" | wc -l)" "${_nodatetimeoriginal}"
  #   read
  # fi

  shopt -u nocaseglob
  shopt -u nullglob
}

_geotag_all() {
  _debug printf "_geotag_all()" 
  # Geotag all files not already geotagged. For videos, fix iOS/macOS 
  # compatibility by transplanting known moov/meta atom into mp4 videos.
  shopt -s nocaseglob
  shopt -s nullglob

  # Store gpx.fmt in script so we don't have extra files
  # From https://github.com/exiftool/exiftool/blob/master/fmt_files/gpx.fmt
  cat <<HEREDOC > "${_GPX_FMT_PATH}"
#------------------------------------------------------------------------------
# File:         gpx.fmt
#
# Description:  Example ExifTool print format file to generate a GPX track log
#
# Usage:        exiftool -p gpx.fmt -ee FILE [...] > out.gpx
#
# Requires:     ExifTool version 10.49 or later
#
# Revisions:    2010/02/05 - P. Harvey created
#               2018/01/04 - PH Added IF to be sure position exists
#               2018/01/06 - PH Use DateFmt function instead of -d option
#               2019/10/24 - PH Preserve sub-seconds in GPSDateTime value
#
# Notes:     1) Input file(s) must contain GPSLatitude and GPSLongitude.
#            2) The -ee option is to extract the full track from video files.
#            3) The -fileOrder option may be used to control the order of the
#               generated track points when processing multiple files.
#------------------------------------------------------------------------------
#[HEAD]<?xml version="1.0" encoding="utf-8"?>
#[HEAD]<gpx version="1.0"
#[HEAD] creator="ExifTool \$ExifToolVersion"
#[HEAD] xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
#[HEAD] xmlns="http://www.topografix.com/GPX/1/0"
#[HEAD] xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
#[HEAD]<trk>
#[HEAD]<number>1</number>
#[HEAD]<trkseg>
#[IF]  \$gpslatitude \$gpslongitude
#[BODY]<trkpt lat="\$gpslatitude#" lon="\$gpslongitude#">
#[BODY]  <ele>\$gpsaltitude#</ele>
#[BODY]  <time>\${DateTimeOriginal#;my (\$ss)=/\.\d+/g;DateFmt("%Y-%m-%dT%H:%M:%S%z");s/Z/\${ss}Z/ if \$ss}</time>
#[BODY]</trkpt>
#[TAIL]</trkseg>
#[TAIL]</trk>
#[TAIL]</gpx>
HEREDOC

  # Make gpx file of all files (pics and vids), using datetimeoriginal which 
  # seems more robust than gpsdatetime used originally in gpx.fmt. Also use 
  # explicit timezone in gpx file instead of ignoring timezone. Note that 
  # this breaks the subsecond accuracy as the Z is no longer part of the 
  # timestamp string and thus cannot be replaced by \${ss}Z.
  # @TODO fix or remove subsecond accuracy in gpx.fmt template
  ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -overwrite_original -if '$GPSLatitude and $DateTimeOriginal' -fileOrder FileModifyDate -p "${_GPX_FMT_PATH}" "${_SOURCE_DIR}"/*{png,jpg,mov,mp4} > "${_EXPORT_DIR}/log.gpx" || true

  # If we did not find any geotags (i.e. log.gpx is empty), we can skip the 
  # rest here
  if [[ ! -s "${_EXPORT_DIR}/log.gpx" ]]; then
    return
  fi

  # Apply geotag to files 
  # without geotag. In my workflow this is mostly videos as my GUI doesn't 
  # accept these. Add || true in case all files already have geotag
  # Set maximum extrapolation to 5 hours. Some tag is better than no tag.
  # https://exiftool.org/forum/index.php?topic=7330.0
  # https://exiftool.org/geotag.html
  # @TODO: use either DateTimeOriginal or DateCreated for videos, whichever is available.
  ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -overwrite_original -if 'not $GPSLatitude' -api GeoMaxExtSecs=18000 -geotag "${_EXPORT_DIR}/log.gpx" "-geotime<DateTimeOriginal" "-geotime<CreateDate" -P "${_EXPORT_DIR}"/ || true

  # Other solutions (kept here for reference)  
  # https://exiftool.org/forum/index.php?topic=5977.0
  # https://exiftool.org/forum/index.php?topic=7826.0
  # exiftool "-xmp:GPSLongitude<GPSLongitude" "-xmp:GPSLatitude<GPSLatitude"
  # http://mit-webaction.sakura.ne.jp/xx_nouse/pd2/lib/exiftool/html/geotag.html
  # exiftool -geotag log.gpx "-xmp:geotime<DateTimeOriginal" dir

  # Now convert XMP geotag to iOS/macOS compatible geotag by inserting a 
  # moov/meta atom into the mp4 file. We use a known-working moov/meta atom
  # from an iOS video as template and edit geotag and timestamp, then insert 
  # into new mp4

  # Store known moov/meta template to disk for updating. Aqcuired via:
  #   mp4extract mp4extract moov/meta moov-meta-atom.bin
  #   base64 moov-meta-atom.bin
  # and then anonymize datetime / geotag
  cat <<HEREDOC | base64 --decode > "${_MOOV_META_PATH}"
AAABt21ldGEAAAAiaGRscgAAAAAAAAAAbWR0YQAAAAAAAAAAAAAAAAAAAAAAyWtleXMAAAAAAAAABQAAACxtZHRhY29tLmFwcGxlLnF1aWNrdGltZS5sb2NhdGlvbi5JU082NzA5AAAAIG1kdGFjb20uYXBwbGUucXVpY2t0aW1lLm1ha2UAAAAhbWR0YWNvbS5hcHBsZS5xdWlja3RpbWUubW9kZWwAAAAkbWR0YWNvbS5hcHBsZS5xdWlja3RpbWUuc29mdHdhcmUAAAAobWR0YWNvbS5hcHBsZS5xdWlja3RpbWUuY3JlYXRpb25kYXRlAAAAxGlsc3QAAAAyAAAAAQAAACpkYXRhAAAAAQAAAAArMTIuMzQ1NiswMDEuMjM0NS0wMDEuNTEwLwAAAB0AAAACAAAAFWRhdGEAAAABAAAAAEFwcGxlAAAAIQAAAAMAAAAZZGF0YQAAAAEAAAAAaVBob25lIDZzAAAAHAAAAAQAAAAUZGF0YQAAAAEAAAAAMTMuMwAAADAAAAAFAAAAKGRhdGEAAAABAAAAADIwMjAtMDEtMDFUMDA6MDA6MDArMDAwMA==
HEREDOC

  local _file
  local _hasmoovmeta
  local _filedate
  local _geotag_dec
  local -a _geotag_dec_arr
  local _geotag_dec_str

  for _file in "${_EXPORT_DIR}"/*mp4; do
  # ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '$GPSLatitude' -p '$filename' "${_EXPORT_DIR}"/*mp4 | while read -r _file; do
    # Check if moov/meta atom is absent by checking if mp4extract gives an 
    # error. If no error, the atom is present, video is already ok, skip
    _hasmoovmeta=1
    ${_PROG_MP4EXTRACT} moov/meta "${_file}" /tmp/out.log 2>/dev/null|| _hasmoovmeta=0
    if [[ ${_hasmoovmeta} -eq 1 ]]; then
      _debug printf "${_file} already has moov/meta atom, skipping"
      continue
    fi

    # Get geotag as decimal from file. All files should have this after above
    # exiftool -geotag command.
    _geotag_dec=$(${_PROG_EXIFTOOL} -n -p '$gpslatitude,$gpslongitude' "${_file}")
    if [[ -z "${_geotag_dec}" ]]; then
      _debug printf "Warning: ${_file} does not have geotag although we expected this, skipping"
      continue
    fi      
    # Use IFS temporarily to split string. Only works if split char is 1 character
    # https://stackoverflow.com/questions/10586153/split-string-into-an-array-in-bash
    IFS=','; read -ra _geotag_dec_arr <<< "$_geotag_dec"; unset IFS
    
    # Geo latitude should be 8 chars long: sign, two digits (0-90), comma, four digits
    # Geo longitude should be 9 chars long: sign, three digits (0-180), comma, four digits
    _geotag_dec_str=$(printf "%+08.4f%+09.4f" "${_geotag_dec_arr[0]}" "${_geotag_dec_arr[1]}")

    # Transplant GPS coordinates @ 0x113, which is a 17 byte string
    # echo "0000113: $(echo -n "+12.3456+001.2345" | xxd -p)" | xxd -r -c 17 - xxd.1
    echo "0000113: $(echo -n "${_geotag_dec_str}" | xxd -p)" | xxd -r -c 17 - "${_MOOV_META_PATH}"

    # Get file date as seconds since unix epoch, then format into date string
    # Transplant ISO 8601 datetime @ 0x19f, a 24 byte string. Remove : in 
    # timezone to be compatible with Apple
    _filedate=$(gdate --date="@$(gstat --format "%W" "${_file}")" +%Y-%m-%dT%H:%M:%S%z)
    _debug printf "$(basename "${_file}"): inserting ${_geotag_dec_str} - ${_filedate}"
    echo "000019f: $(echo "${_filedate}" | xxd -p)" | xxd -r -c 24 - "${_MOOV_META_PATH}"

    # Finally, insert moov/meta atom into output mp4 file
    ${_PROG_MP4EDIT} --insert moov:"${_MOOV_META_PATH}" "${_file}" "${_file}-moov-meta.mp4"

    # Fix timestamp (only file, metadata is OK)
    _touch_file_ref "${_file}" "${_file}-moov-meta.mp4"
    mv "${_file}-moov-meta.mp4" "${_file}"
  done

  shopt -u nocaseglob
  shopt -u nullglob
}

_prep_output() {
  _debug printf "_prep_output()" 
  # Source_dir should be like 20101003_holiday_italy_rome_verona, output 
  # directory will replace _ by space so iOS Photos app can search for 
  # individual words
  local _SOURCE_DIR_ABS
  _SOURCE_DIR_ABS="$(cd "${_SOURCE_DIR}" && pwd -P)"
  _EXPORT_DIR=${_EXPORT_ROOT}/$(basename "${_SOURCE_DIR_ABS:-"0"}" | tr "_" " ")
  if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
    mkdir -p "${_EXPORT_DIR}"
  fi
}

_convert_pics() {
  if [[ "${_CONV_PICS:-"0"}" -eq 0 ]]; then
    return
  fi
  _debug printf "_convert_pics()" 
  local _file
  local _mime

  shopt -s nocaseglob
  shopt -s nullglob

  # Check if we have any files
  if [[ -z "$(echo "${_SOURCE_DIR}"/*{png,jpg})" ]]; then
    printf "Warning: no pictures found, are you sure source dir is correct?\n"
    return
  fi

  # for _file in $(${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{png,jpg}); do
  ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{png,jpg} | while read -r _file; do
    _debug printf "${_file}"
    # # Use mime-type to distinguish between video and images
    _mime=$(${_PROG_FILE} --brief --mime-type "${_SOURCE_DIR}/${_file}")
    if [[  "${_mime}" =~ ^image/ ]]; then
      _debug printf "%s Parsing image" "${_file}"
      # Use \> to only resize larger images than desired size 
      # http://www.imagemagick.org/Usage/resize/#shrink
      # https://stackoverflow.com/a/6387086
      if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
        # https://stackoverflow.com/questions/7261855/recommendation-for-compressing-jpg-files-with-imagemagick#7262050
        # https://developers.google.com/speed/docs/insights/OptimizeImages
        ${_PROG_CONVERT} -geometry 1920x1920\> -quality 60 "${_SOURCE_DIR}/${_file}" "${_EXPORT_DIR}/${_file}"
      fi
    else
      _debug printf "%s Unsupported mime-type: %s" "${_file}" "${_mime}"
      continue
    fi

    # Always set newly created file datetime to original datetime
    if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
      _touch_file_ref "${_SOURCE_DIR}/${_file}" "${_EXPORT_DIR}/${_file}"
    fi
 done
 # This results in ambiguous redirect. Somehow the multiple globs (*{png,jpg,avi,mov,mp4}) are split in parallel, causing the while read loop to choke? 
 # done < <(${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{png,jpg,avi,mov,mp4})

  shopt -u nocaseglob
  shopt -u nullglob
}

_convert_vids() {
  if [[ "${_CONV_VIDS:-"0"}" -eq 0 ]]; then
    return
  fi

  _debug printf "_convert_vids()" 
  local _file
  local _outfile
  local _mime
  local _framerate
  local _isiphone

  shopt -s nocaseglob
  shopt -s nullglob

  # Check if we have any files
  if [[ -z "$(echo "${_SOURCE_DIR}"/*{avi,mov,mp4})" ]]; then
    printf "Warning: no videos found, are you sure source dir is correct?\n"
    return
  fi

  # for _file in $(${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{avi,mov,mp4}); do
  ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{avi,mov,mp4} | while read -r _file; do
    _debug printf "${_file}"
    # # Use mime-type to ensure we have a video file
    _mime=$(${_PROG_FILE} --brief --mime-type "${_SOURCE_DIR}/${_file}")
    if [[ "${_mime}" =~ ^video/ ]]; then
      _debug printf "%s Parsing video" "${_file}"
      
      # We cannot easily process slo-mo videos with ffmpeg, so we skip these.
      # We detect these by checking for framerate > 30. To ensure we can do
      # integer comparison, we take the string before the decimal period
      # for comparison (${var%\.*})
      _framerate=$(${_PROG_EXIFTOOL} -printFormat '$videoframerate' "${_SOURCE_DIR}/${_file}")
      # /Users/tim/Pictures/2017/20170720_timelapse_balkon_iphone/IMG_2564.MOV
      if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
        # If filename ends in -x264_aac.mp4, we've already converted the 
        # movie in the source directory. In that case, simply copy the file 
        # as we probably won't save much space anymore
        if [[ "${_SOURCE_DIR}/${_file}" =~ -x264_aac.mp4$ ]]; then
          _debug printf "${_file} already converted, copying instead."
          _outfile="${_file}"
          cp -p "${_SOURCE_DIR}/${_file}" "${_EXPORT_DIR}/"
          continue
        elif [[ "${_framerate%\.*}" -gt 30 ]]; then
          echo -n "Warning: cannot process slo-mo video. Please convert in QuickTime (Player) manually, OK?"
          # read answer
          continue
        else
          # Convert to nice file format. Get the video metadata date 
          # from the modification time (stat) of the source file
          # Reduce output clutter: -hide_banner -nostats -loglevel error 
          # Copy all metadata: -movflags use_metadata_tags -- https://superuser.com/questions/1208273/add-new-and-non-defined-metadata-to-a-mp4-file -- https://video.stackexchange.com/questions/23741/how-to-prevent-ffmpeg-from-dropping-metadata
          # We want ~1 MPixel max video size (1280x720) and no upscaling, 
          # use -2 to ensure even width/height:
          # iw*min(1,sqrt(1280*720/ih/iw)):-2
          # https://unix.stackexchange.com/questions/190431/convert-a-video-to-a-fixed-screen-size-by-cropping-and-resizing
          # https://trac.ffmpeg.org/wiki/Scaling
          _outfile="${_file}-x264_aac.mp4"
          nice -n 15 ${_PROG_FFMPEG} -hide_banner -nostdin -nostats -loglevel error -i "${_SOURCE_DIR}/${_file}" -profile:v high -level 4.0 -pix_fmt yuv420p -c:v libx264 -preset slower -movflags use_metadata_tags -crf 28 -vf "scale='iw*min(1,sqrt(1280*720/ih/iw)):-2" -c:a libfdk_aac -vbr 3 -threads 0 -y "${_EXPORT_DIR}/${_outfile}"
        fi
        _debug printf "${_file} Conversion done"

        _isiphone=$(${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -printFormat '$make' "${_SOURCE_DIR}/${_file}")
        if  [[ "${_isiphone:-"0"}" = 'Apple' ]]; then
          # Fix GPS metadata by transplanting literal with https://www.bento4.com/
          # @TODO Also geotag non-iphone videos like this by creating a dummy moov/meta-file and then inserting it in the output video file
          if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
            _debug printf "${_file} Fixing/transplanting iOS geotag"
            ${_PROG_MP4EXTRACT} moov/meta "${_SOURCE_DIR}/${_file}" "${_MOOV_META_PATH}"
            ${_PROG_MP4EDIT} --insert moov:"${_MOOV_META_PATH}" "${_EXPORT_DIR}/${_outfile}" "${_EXPORT_DIR}/${_outfile}-gps"
            mv "${_EXPORT_DIR}/${_outfile}-gps" "${_EXPORT_DIR}/${_outfile}"
          fi
        fi
      fi
    else
      _debug printf "%s Unsupported mime-type: %s" "${_file}" "${_mime}"
      continue
    fi
  # Always set newly created file datetime to original datetime
  if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
    _debug printf "${_file} Setting timestamp"
    _touch_file_ref "${_SOURCE_DIR}/${_file:-0}" "${_EXPORT_DIR}/${_outfile:-0}"
    # For videos created with ffmpeg, also set metadata dates from the filemodifydate, as ffmpeg does not transfer metadata dates correctly
    ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" '-time:all<$FileModifyDate' -overwrite_original -wm w -P "${_EXPORT_DIR}/${_outfile:-0}"
    # ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -overwrite_original "-FileCreateDate<DateTimeOriginal" -P "${_EXPORT_DIR}/${_file}-x264_aac.mp4"
  fi
 done
 # This results in ambiguous redirect. Somehow the multiple globs (*{png,jpg,avi,mov,mp4}) are split in parallel, causing the while read loop to choke? 
 # done < <(${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{png,jpg,avi,mov,mp4})

  shopt -u nocaseglob
  shopt -u nullglob
}

_tag_pics() {
  if [[ "${_CONV_PICS:-"0"}" -eq 0 ]]; then
    return
  fi

  _debug printf "_tag_pics()"
  # After converting images, set keywords on all newly converted files. Assume our exportdir is formatted as follows: <date> <keyword1> <keyword2> <keywordN>, each keyword space-separated. Here we apply all of exportdir as one keyword, as well as all keywords (i.e. the second word onward) as individual keywords.

  shopt -s nocaseglob
  shopt -s nullglob
  local _albumdir_tag
  local _albumdir_tag_nodate
  local _exiftags


  # All tags in lower case to reduce number of unique keywords
  _albumdir_tag=$(basename "${_EXPORT_DIR}" | tr '[:upper:]' '[:lower:]')
  local -a _exiftags=("-IPTC:Keywords+=${_albumdir_tag}")
  local -a _pngtags=("-XMP:Subject+=${_albumdir_tag}")
  
  # Skip date (=first space-separated word) in separate keywords, then add the rest if length is more than 2 letters
  _albumdir_tag_nodate=${_albumdir_tag#* }
  # Loop over words in string, add all words >2 characters as keyword
  # https://stackoverflow.com/a/30212526
  local -a _albumdir_tag_nodate_arr
  read -ra _albumdir_tag_nodate_arr <<< "${_albumdir_tag_nodate}"
  for _keyword in "${_albumdir_tag_nodate_arr[@]}"; do
      if [ "${#_keyword}"  -gt 2 ]; then
          _exiftags+=("-IPTC:Keywords+=${_keyword}")
          _pngtags+=("-XMP:Subject+=${_keyword}")
      fi
  done
  # Add png tags and exif tags separately
  # See https://stackoverflow.com/questions/19154596/exiftool-to-create-osx-visible-xmp-metadata-in-png-images
  # 
  if [[ -n "$(echo "${_EXPORT_DIR}"/*png)" ]]; then
    if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
      ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -overwrite_original "${_pngtags[@]}" -P "${_EXPORT_DIR}"/*png
    fi
  fi
  if [[ -n "$(echo "${_EXPORT_DIR}"/*jpg)" ]]; then
    if [[ "${_DRY_RUN:-"0"}" -eq 0 ]]; then
      ${_PROG_EXIFTOOL} "${_PROG_EXIFTOOL_OPTS[@]}" -overwrite_original "${_exiftags[@]}" -P "${_EXPORT_DIR}"/*jpg
    fi
  fi

  shopt -u nocaseglob
  shopt -u nullglob
}

_publish_pics() {
  _debug printf ">> Performing operation...\\n"

  _check_prereq

  _prep_input

  _prep_output

  _convert_pics

  _tag_pics

  _convert_vids

  _geotag_all

}

###############################################################################
# Main
###############################################################################

# _main()
#
# Usage:
#   _main [<options>] [<arguments>]
#
# Description:
#   Entry point for the program, handling basic option parsing and dispatching.
_main() {
  if ((_PRINT_HELP))
  then
    _print_help
  else
    _publish_pics "$@"
  fi
}

# Call `_main` after everything has been defined.
_main "$@"
