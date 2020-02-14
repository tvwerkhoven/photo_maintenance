#!/usr/bin/env bash
#
# Convert Picasa rating from .picasa files to IPTC rating in JPG files 
# themselves.
#
# Based on:
# Bash Boilerplate: https://github.com/alphabetum/bash-boilerplate
#
# Copyright (c) 2015 William Melody • hi@williammelody.com


# Short form: set -u
set -o nounset

# Short form: set -e
set -o errexit

# Print a helpful message if a pipeline with non-zero exit code causes the
# script to exit as described above.
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR

# Allow the above trap be inherited by all functions in the script.
#
# Short form: set -E
set -o errtrace

# Return value of a pipeline is the value of the last (rightmost) command to
# exit with a non-zero status, or zero if all commands in the pipeline exit
# successfully.
set -o pipefail

# Set $IFS to only newline and tab.
#
# http://www.dwheeler.com/essays/filenames-in-shell.html
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
picsa2iptc -- convert Picasa picture rating to IPTC keywords

Usage:
  ${_ME} [--picasa-file <picasafile>] [<target dir>]
  ${_ME} -h | --help

Options:
  -h --help  Display this help information.
  --picasa-file Specify which picasa file to look for, default .picasa.ini
HEREDOC
}

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0

# Initialize additional expected option variables.
_OPTION_TARGETDIR="."
_OPTION_PICASA_FILE=".picasa.ini"

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
    --picasa-file)
      _require_argument "${__option}" "${__maybe_param}"
      _OPTION_PICASA_FILE="${__maybe_param}"
      shift
      ;;    --endopts)
      # Terminate option parsing.
      break
      ;;
    -*)
      _die printf "Unexpected option: %s\\n" "${__option}"
      ;;
    *)
      # Use any argument as target dir
      _OPTION_TARGETDIR="${__option}"
      ;;
  esac
  shift
done

###############################################################################
# Program Functions
###############################################################################

_picasa2iptc() {
  _debug printf ">> Performing operation...\\n"

  # Loop over all directories recursively, find picasa files
  local _dir
  find "${_OPTION_TARGETDIR}" -type d | while read _dir; do
    test ! -f "${_dir}/${_OPTION_PICASA_FILE}" && continue
    # .picasa.ini is formatted as follows
    cat "${_dir}/${_OPTION_PICASA_FILE}" | tr -d "\r" | grep "^star=yes\|^\["  | pcregrep -M "\]\nstar" || true | grep "^\[" || true | tr -d "[]"
    break
  done
  return
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
    _picasa2iptc "$@"
  fi
}

# Call `_main` after everything has been defined.
_main "$@"
