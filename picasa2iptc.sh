#!/usr/bin/env bash
#
# Convert Picasa rating from .picasa files to IPTC rating in JPG files 
# themselves.
#
# Based on:
# Bash Boilerplate: https://github.com/alphabetum/bash-boilerplate
# Copyright (c) 2015 William Melody • hi@williammelody.com

# set -xv
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
picsa2iptc -- convert Picasa picture rating to IPTC/XMP rating=5 via exiftool

Usage:
  ${_ME} [--picasa-file <picasafile>] [--dry-run] [--debug] [<target dir>]
  ${_ME} -h | --help

Options:
  -h --help  Display this help information.
  --picasa-file Specify which picasa file to look for, default *icasa.ini
  --starred  Set rating on files which have star=yes in picasa file (default)
  --any      Set rating on any picture listed in picasa file
  --dry-run  Only print number of starred files found per directory
HEREDOC
}

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0
_DRY_RUN=0

# Initialize additional expected option variables.
_OPTION_TARGETDIR="."
_OPTION_PICASA_FILE="*icasa.ini"
_OPTION_TAG_STARRED=0
_OPTION_TAG_ANY=0

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
    --starred)
      _OPTION_TAG_STARRED=1
      ;;
    --any)
      _OPTION_TAG_ANY=1
      ;;
    --debug)
      _USE_DEBUG=1
      ;;
    --dry-run)
      _DRY_RUN=1
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
  _debug printf ">> Performing operation on ${_OPTION_TARGETDIR}...\\n"

  # Loop over all directories recursively, find picasa files
  local _dir
  local _picasafile
  local -a _manualstarfiles=()
  local -a _unfoundstarfiles=()
  while read -r _picasafile; do
    _dir=$(dirname "${_picasafile}")
    _debug printf ">> parsing ${_dir}...\\n"

    # .picasa.ini is formatted as follows
    # [IMG_2494.JPG]
    # prop=X
    # star=yes

    # Loop over lines, get rid of \r, if we find a file, formatted as 
    # [<filename>], store it, then look for star=yes. Based on https://github.com/rudimeier/bash_ini_parser
    local _secpat="^\[[^\]*\]$"
    local _iniline
    local _inifile
    local -a _starfiles=()
    while read -r _iniline; do
      # Section marker? Should be [, anything but ], then ].
      if [[ "${_iniline}" =~ $_secpat ]]; then
        _inifile="${_iniline#[}"
        _inifile="${_inifile%%]}"

        # If --any is given, tag any file.
        # @TODO warning code duplication
        if [[ "${_OPTION_TAG_ANY:-"0"}" -eq 1 ]]; then
          # Check if file exists
          _debug printf ">> Trying to add ${_inifile} because of --any\\n"
          if ! [[ -f "${_dir}/${_inifile}" ]]; then
            printf "Warning: starred file not found: %s\\n" "${_dir}/${_inifile}"
            _unfoundstarfiles+=("${_dir}/${_inifile}")
          # Check if file is supported by exiftool (not AVI, see https://www.exiftool.org/#supported)
          elif [[ "${_inifile##*\.}" == "AVI" ]] || [[ "${_inifile##*\.}" == "avi" ]]; then
            # printf "Warning: cannot tag AVIs with exiftool, please process manually: %s\\n" "${_dir}/${_inifile}"
            # store problem files for later reporting
            _manualstarfiles+=("${_dir}/${_inifile}")
          else
            _starfiles+=("${_dir}/${_inifile}")
          fi
        fi
      # Look for star=yes line. Every time we find this line, the most recent 
      # file will be set to iptc rating=5 if --starred is given
      elif [[ "${_iniline}" =~ ^star=yes$ && "${_OPTION_TAG_STARRED:-"0"}" -eq 1 ]]; then
        # Check if file exists
        _debug printf ">> Trying to add ${_inifile} because of --starred\\n"
        if ! [[ -f "${_dir}/${_inifile}" ]]; then
          printf "Warning: starred file not found: %s\\n" "${_dir}/${_inifile}"
          _unfoundstarfiles+=("${_dir}/${_inifile}")
        # Check if file is supported by exiftool (not AVI, see https://www.exiftool.org/#supported)
        elif [[ "${_inifile##*\.}" == "AVI" ]] || [[ "${_inifile##*\.}" == "avi" ]]; then
          # printf "Warning: cannot tag AVIs with exiftool, please process manually: %s\\n" "${_dir}/${_inifile}"
          # store problem files for later reporting
          _manualstarfiles+=("${_dir}/${_inifile}")
        else
          _starfiles+=("${_dir}/${_inifile}")
        fi
      fi
    done < <(cat "${_picasafile}" | tr -d "\r")
    _debug printf ">> Found star file list: ${_starfiles[*]:-}\\n"

    # Given list of files, tag in IPTC
    if ((_DRY_RUN))
    then
      printf "%s: found %s starred files\\n" "${_dir}" "${#_starfiles[@]}"
    else
      if [[ "${#_starfiles[@]}" -gt 0 ]]; then
        # Count number of files found that already have rating
        local _starred=$(exiftool -q -if 'not $rating' -printFormat '$filename' "${_starfiles[@]:-}" | wc -l || true)
        printf "%s: found %s starred files of which %s without rating\\n" "${_dir}" "${#_starfiles[@]}" "${_starred}"
        
        # -P to prevent changing the ModifyDate
        # -quiet to not give output except warnings/errors
        # Only update files that do not have a rating already
        exiftool -q -P -if 'not $rating' -rating=5 -overwrite_original "${_starfiles[@]:-}" || true
      fi
    fi
  done < <(find "${_OPTION_TARGETDIR}" -type f -name "${_OPTION_PICASA_FILE}" | sort)

  if [[ "${#_manualstarfiles[@]}" -gt 0 ]]; then
    printf "Warning: process these files manually:\n %s\n" "${_manualstarfiles[*]:-}"
  fi
  if [[ "${#_unfoundstarfiles[@]}" -gt 0 ]]; then
    printf "Warning: fix these unfound files manually:\n %s\n" "${_unfoundstarfiles[*]:-}"
  fi


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
  if ((_OPTION_TAG_STARRED && _OPTION_TAG_ANY))
  then
    _die printf "Options --any and --starred are mutually exclusive\n"
  fi

  if ((_PRINT_HELP))
  then
    _print_help
  else
    _picasa2iptc "$@"
  fi
}

# Call `_main` after everything has been defined.
_main "$@"
