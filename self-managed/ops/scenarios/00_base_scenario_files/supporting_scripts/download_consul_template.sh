#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

## Prints a line on stdout prepended with date and time
_log() {
  echo -e "\033[1m["$(date +"%Y-%d-%d %H:%M:%S")"] -- ${@}\033[0m"
}

_header() {
  echo -e "\033[1m[$(date +'%Y-%d-%d %H:%M:%S')]\033[1m\033[33m [`basename $0`] - ${@}\033[0m"  
}

_log_err() {
  DEC_ERR="\033[1m\033[31m[ERROR] \033[0m\033[1m"
  _log "${DEC_ERR}${@}"  
}

_log_warn() {
  DEC_WARN="\033[1m\033[33m[WARN] \033[0m\033[1m"
  _log "${DEC_WARN}${@}"  
}

# ++-----------------+
# || Variables       |
# ++-----------------+


# ++-----------------+
# || Begin           |
# ++-----------------+