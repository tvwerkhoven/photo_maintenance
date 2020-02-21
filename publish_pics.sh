#!/usr/bin/env bash
#
# # About
#_convert_pics
# Publish selected pictures and videos for web-sharing (i.e. smaller), which
# can subsequently be copied to iPhone so one can store more pics on a phone
#
# # Usage
#   ./publish_pics.sh <source_dir> <export_dir>
#
# # Processing
#
# For all images/videos (png, mov, mp4, jpg) with the 'rating' parameter set 
# in <source_dir>, convert to lower resolution and store in <export_dir>.
# The script will make a new directory in <export_dir> named <source_dir>,
# where _ are replaced with space. This enables iOS >12 to look for these 
# folders as keywords when
# 
# For images: downscale max resolution to 1920 pixels, quality 70, jpeg
# For videos: convert to x264 with quality crf 23 and max resolution 1280 and 
#             aac audio with vbr 3 rate (48-56 kbps/channel)
#
# # Examples
#   ./publish_pics.sh ~/Pictures/200600519_wedding_party_new_york ./Pictures/pics_lossy
# will create a folder "200600519 wedding party new york" in ./Pictures/pics_lossy
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
  ${_ME} -h | --help --dry-run -s | --sourcedir

Options:
  -h --help  Display this help information.
  --dry-run  Only check which files would be copied, do not convert/copy
  -s --sourcedir Directory to read from, defaults to current dir
  <export_root> Directory to create output directory and files in
HEREDOC
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

_PROG_EXIFTOOL=/opt/local/bin/exiftool
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
    --no-vids)
      _CONV_VIDS=0
      ;;
    --no-pics)
      _CONV_PICS=0
      ;;
    --dry-run)
      _DRY_RUN=1
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

  # We need to match by extension case insensitively

}

_prep_input() {
  _debug printf "_prep_input()" 
  # First set file date to creation date from metadata, movies and images 
  # separately because different tags. Use -wm w to not create new tags
  # See: https://photo.stackexchange.com/questions/83657/any-program-to-change-date-created-of-videos-to-actual-exif-data
  # Not sure which works reliably for videos
  # See: https://exiftool.org/forum/index.php?topic=6318.msg33921#msg33921

  # Set case insensitive glob and nullglob (such that lack of file hit will 
  # give null back instead of the glob string)
  shopt -s nocaseglob
  shopt -s nullglob

  # First check if files exist to ensure exiftool is happy. The metadata 
  # setting might fail because tags don't exist or cannot be written. Ignore 
  # for now

  if [[ "${_CONV_VIDS:-"0"}" -eq 1 && -n "$(echo "${_SOURCE_DIR}"/*{avi,mov,mp4})" ]]; then
    _debug printf "Preparing timestamps on movies"
    # ${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors "-CreationDate>FileModifyDate" -wm w "${_SOURCE_DIR}"/*{avi,mov,mp4}
    # ${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors "-CreateDate>FileModifyDate" -wm w "${_SOURCE_DIR}"/*{avi,mov,mp4}
  fi
  if [[ "${_CONV_PICS:-"0"}" -eq 1 && -n "$(echo "${_SOURCE_DIR}"/*{png,jpg})" ]]; then
    _debug printf "Preparing timestamps on pictures"
    ${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors "-DateTimeOriginal>FileModifyDate" -wm w "${_SOURCE_DIR}"/*{png,jpg}
    # If no exif timestamps, set here from filedate. Note that if no files 
    # match the criterium, exiftool will return error code 2, hence we OR 
    # this with true to ensure we don't quit on this command
    # See https://exiftool.org/exiftool_pod.html#if-NUM-EXPR
    ${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors -if '(not $datetimeoriginal)' "-FileModifyDate>DateTimeOriginal" ${_SOURCE_DIR}/*{png,jpg} || true
  fi

  shopt -u nocaseglob
  shopt -u nullglob
}

_prep_output() {
  _debug printf "_prep_output()" 
  # Source_dir should be like 20101003_holiday_italy_rome_verona, output 
  # directory will replace _ by space so iOS Photos app can search for 
  # individual words
  _EXPORT_DIR=${_EXPORT_ROOT}/$(basename "${_SOURCE_DIR}" | tr "_" " ")
  mkdir -p "${_EXPORT_DIR}"
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

  # while read -r _file; do
  for _file in $(${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{png,jpg}); do
    _debug printf "${_file}"
    # # Use mime-type to distinguish between video and images
    _mime=$(${_PROG_FILE} --brief --mime-type "${_SOURCE_DIR}/${_file}")
    if [[  "${_mime}" =~ ^image/ ]]; then
      _debug printf "%s Parsing image" "${_file}"
      # Use \> to only resize larger images than desired size 
      # http://www.imagemagick.org/Usage/resize/#shrink
      # https://stackoverflow.com/a/6387086
      ${_PROG_CONVERT} -geometry 1920x1920\> -quality 70 ${_SOURCE_DIR}/${_file} "${_EXPORT_DIR}/${_file}"
    else
      _debug printf "%s Unsupported mime-type: %s" "${_file}" "${_mime}"
    fi

    # Always set newly created file datetime to original datetime
    ${_PROG_TOUCH} -r "${_SOURCE_DIR}/${_file}" "${_EXPORT_DIR}/${_file}"
    ${_PROG_SETFILE} -d "$(${_PROG_GETFILEINFO} -d ${_SOURCE_DIR}/${_file})" "${_EXPORT_DIR}/${_file}"
 done
 # This results in ambiguous redirect. Somehow the multiple globs (*{png,jpg,avi,mov,mp4}) are split in parallel, causing the while read loop to choke? 
 # done < <(${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{png,jpg,avi,mov,mp4})

  shopt -u nocaseglob
  shopt -u nullglob
}

_convert_vids() {
  if [[ "${_CONV_VIDS:-"0"}" -eq 0 ]]; then
    return
  fi

  _debug printf "_convert_vids()" 
  local _file
  local _mime
  local _isslomo
  local _isiphone

  shopt -s nocaseglob
  shopt -s nullglob

  # while read -r _file; do
  for _file in $(${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{avi,mov,mp4}); do
    _debug printf "${_file}"
    # # Use mime-type to distinguish between video and images
    _mime=$(${_PROG_FILE} --brief --mime-type "${_SOURCE_DIR}/${_file}")
    if [[ "${_mime}" =~ ^video/ ]]; then
      _debug printf "%s Parsing video" "${_file}"
      # From ffmpeg info, look for three-digit fps (xxx.xx fps), which 
      # means it's slomo. We could make this more exact by checking for 
      # fps > 30, but that's too complicated
      # @FIXME this command is very fragile
      _isslomo=$(${_PROG_FFMPEG} -i ${_SOURCE_DIR}/${_file} 2>&1 | grep "[0-9]\{3,\}.[0-9]\{2,\} fps," || true)
      if  [[ -n ${_isslomo} ]]; then
        echo -n "Warning: cannot process slo-mo video. Please convert in QuickTime (Player) manually, OK?"
        read answer
      else
        # Convert to nice file format. Get the video metadata date 
        # from the modification time (stat) of the source file
        # Reduce output clutter: -hide_banner -nostats -loglevel error 
        # Copy all metadata: -movflags use_metadata_tags -- https://superuser.com/questions/1208273/add-new-and-non-defined-metadata-to-a-mp4-file -- https://video.stackexchange.com/questions/23741/how-to-prevent-ffmpeg-from-dropping-metadata
        nice -n 15 ${_PROG_FFMPEG} -hide_banner -nostats -loglevel error -i "${_SOURCE_DIR}/${_file}" -profile:v high -level 4.0 -pix_fmt yuv420p -c:v libx264 -preset ultrafast -movflags use_metadata_tags -crf 28 -vf scale=1280:-1 -c:a libfdk_aac -vbr 3 -threads 0 -y "${_EXPORT_DIR}/${_file}-x264_aac.mp4"
        _debug printf "Conversion done"

        # @FIXME this check for iphone videos is very fragile
        _isiphone=$(echo ${_SOURCE_DIR}/${_file} | grep "IMG_.*MOV" || true)
        if  [[ -n ${_isiphone} ]]; then
          # Fix GPS metadata by transplanting literal with https://www.bento4.com/
          # @TODO Also geotag non-iphone videos like this by creating a dummy moov/meta-file and then inserting it in the output video file
          ${_PROG_MP4EXTRACT} moov/meta "${_SOURCE_DIR}/${_file}" "${_EXPORT_DIR}/metadata-gps"
          ${_PROG_MP4EDIT} --insert moov:"${_EXPORT_DIR}/metadata-gps" "${_EXPORT_DIR}/${_file}-x264_aac.mp4" "${_EXPORT_DIR}/${_file}-x264_aac-gps.mp4"
          mv "${_EXPORT_DIR}/${_file}-x264_aac-gps.mp4" "${_EXPORT_DIR}/${_file}-x264_aac.mp4"
        fi
      fi
    else
      _debug printf "%s Unsupported mime-type: %s" "${_file}" "${_mime}"
    fi

    # Always set newly created file datetime to original datetime
    ${_PROG_TOUCH} -r "${_SOURCE_DIR}/${_file}" "${_EXPORT_DIR}/${_file}"
    ${_PROG_SETFILE} -d "$(${_PROG_GETFILEINFO} -d ${_SOURCE_DIR}/${_file})" "${_EXPORT_DIR}/${_file}"
 done
 # This results in ambiguous redirect. Somehow the multiple globs (*{png,jpg,avi,mov,mp4}) are split in parallel, causing the while read loop to choke? 
 # done < <(${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors -if '$rating' -printFormat '$filename' "${_SOURCE_DIR}"/*{png,jpg,avi,mov,mp4})

  shopt -u nocaseglob
  shopt -u nullglob
}

_tag_pics() {
  if [[ "${_CONV_PICS:-"0"}" -eq 1 ]]; then
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
  # Loop over words in string, add all words >3 characters as keyword
  # https://stackoverflow.com/a/30212526
  local -a _albumdir_tag_nodate_arr
  read -ra _albumdir_tag_nodate_arr <<< "${_albumdir_tag_nodate}"
  for _keyword in "${_albumdir_tag_nodate_arr[@]}"; do
      if [ $(echo $_keyword | wc -c) -gt 3 ]; then
          _exiftags+=("-IPTC:Keywords+=${_keyword}")
          _pngtags+=("-XMP:Subject+=${_keyword}")
      fi
  done
  # Add png tags and exif tags separately
  # See https://stackoverflow.com/questions/19154596/exiftool-to-create-osx-visible-xmp-metadata-in-png-images
  # 
  if [[ -n "$(echo "${_EXPORT_DIR}"/*png)" ]]; then
    ${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors -overwrite_original "${_pngtags[@]}" "-DateTimeOriginal>FileModifyDate" "${_EXPORT_DIR}"/*png
  fi
  if [[ -n "$(echo "${_EXPORT_DIR}"/*jpg)" ]]; then
    ${_PROG_EXIFTOOL} -quiet -quiet -ignoreMinorErrors -overwrite_original "${_exiftags[@]}" "-DateTimeOriginal>FileModifyDate" "${_EXPORT_DIR}"/*jpg
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
