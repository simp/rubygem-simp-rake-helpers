#!/bin/bash
#
# adapted from https://stackoverflow.com/questions/402377/using-getopts-in-bash-shell-script-to-get-long-and-short-command-line-options/7680682#7680682
#
#

optspec=":hv-:"
while getopts "$optspec" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        rpm_section=*)
          val=${OPTARG#*=}
          opt=${OPTARG%=$val}
          echo "Parsing option: '--${opt}', value: '${val}'" >&2
          ;;
        rpm_status=*)
          val=${OPTARG#*=}
          opt=${OPTARG%=$val}
          echo "Parsing option: '--${opt}', value: '${val}'" >&2
          ;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
            echo "Unknown option --${OPTARG}" >&2
          fi
          ;;
      esac;;
    h)
      echo "usage: $0 [-v] [--rpm_section=<value>]" >&2
      exit 2
      ;;
    v)
      echo "Parsing option: '-${optchar}'" >&2
      ;;
    *)
      if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
        echo "Non-option argument: '-${OPTARG}'" >&2
      fi
      ;;
  esac
done
