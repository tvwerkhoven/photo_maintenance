#!/usr/bin/env bash
#
# # About
#
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

# Set $IFS to only newline and tab.
IFS=$'\n\t'

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
  ${_ME} [--options] <export_dir>
  ${_ME} -h | --help --dry-run -s | --sourcedir

Options:
  -h --help  Display this help information.
  --dry-run  Only check which files would be copied, do not convert/copy
  -s --sourcedir  Directory to read from, defaults to current dir
HEREDOC
}

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0
_DRY_RUN=0
# Initialize additional expected option variables.
_EXPORT_DIR=""
_SOURCE_DIR="."

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
      _EXPORT_DIR="${__option}"
      ;;
  esac
  shift
done

if [[ -z "${_EXPORT_DIR}" ]]; then
  _die printf "Error: export dir option required.\\n"
fi

###############################################################################
# Program Functions
###############################################################################

_check_prereq() {
  return
}

_publish_pics() {
  _debug printf ">> Performing operation...\\n"

  _check_prereq

  # if ((_OPTION_X))
  # then
  #   printf "Perform a simple operation with --option-x.\\n"
  # else
  #   printf "Perform a simple operation.\\n"
  # fi
  # if [[ -n "${_SHORT_OPTION_WITH_PARAMETER}" ]]
  # then
  #   printf "Short option parameter: %s\\n" "${_SHORT_OPTION_WITH_PARAMETER}"
  # fi
  # if [[ -n "${_LONG_OPTION_WITH_PARAMETER}" ]]
  # then
  #   printf "Long option parameter: %s\\n" "${_LONG_OPTION_WITH_PARAMETER}"
  # fi
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
