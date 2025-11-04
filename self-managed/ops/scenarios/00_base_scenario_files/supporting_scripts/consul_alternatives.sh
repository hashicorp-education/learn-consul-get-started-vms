#!/usr/bin/env bash

_BIN_POOL_LOCATION=~/.bin/consul

_BIN_LOCATION=/usr/local/bin


mkdir -p "${_BIN_POOL_LOCATION}"

_get_consul_versions() {

    _available_versions=

}



_init() {

    _consul_bin=`which consul`

    if [ -z "${_consul_bin}" ]; then

        _cur_version=`${_consul_bin} version -format json | jq -r .Version`
    
    else

    fi

} 


case $i in

  PATTERN_1)
    STATEMENTS
    ;;

  PATTERN_2)
    STATEMENTS
    ;;

  PATTERN_N)
    STATEMENTS
    ;;

  *)
    STATEMENTS
    ;;
esac
