#!/bin/bash
#
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2020-2021, Intel Corporation
#

#
# create_report_figures.sh -- generate Figures and Appendix charts for
# a performance report (EXPERIMENTAL)
#
# Note: The DATA_PATH variable has to point directories of the following
# structure:
# .
# ├── READ
# │   ├── MACHINE_A
# │   │   ├── DRAM
# │   │   │   └── *
# │   │   │       └── CSV
# │   │   │           ├── ...
# │   │   │           └── *.csv
# │   │   └── PMEM
# │   │       └── *
# │   │           └── CSV
# │   │               ├── ...
# │   │               └── *.csv
# │   ├── MACHINE_B
# │   │   └── ...
# │   └── ...
# └── WRITE
#     └── ...
#
# Note: It is assumed APM is ALWAYS used when DDIO is turned OFF on the target
# side whereas for GPSPM DDIO is turned ON on the target side. If one would like
# to e.g. generate a comparison between either APM or GPSPM for both DDIO
# turned ON and OFF but on the client-side, you should use other available
# mechanisms e.g. by creating separate directories:
# - MACHINE_A_DDIO_ON
# - MACHINE_A_DDIO_OFF
#

echo "This tool is EXPERIMENTAL"

function usage()
{
    echo "Error: $1"
    echo
    echo "usage: $0"
    echo
    echo "export DATA_PATH=/custom/data/path"
    echo "export STAMP=CUSTOM_REPORT_STAMP"
    echo "export READ_LAT_MACHINE=NAME_OF_THE_MACHINE # a machine used to generate the Figure_2_3_4"
    echo "export READ_BW_MACHINE=NAME_OF_THE_MACHINE # a machine used to generate the Figure_5 and Figure_6"
    echo "export WRITE_LAT_MACHINE=NAME_OF_THE_MACHINE # a machine used to generate the Figure_7"
    echo "export WRITE_BW_MACHINE=NAME_OF_THE_MACHINE"
    exit 1
}

if [ "$#" -ne "0" ]; then
    usage "too many arguments"
elif [ -z "$DATA_PATH" ]; then
	usage "DATA_PATH not set"
fi

N_DIGITS=3

function echo_filter()
{
    for f in $*; do
        echo $f
    done
}

function files_to_machines()
{
    for f in $*; do
        echo "$f" | sed -E 's/.*MACHINE_([0-9A-Za-z_]+).*/\1/'
    done
}

function lat_appendix()
{
    filter="$1"
    no="$2"
    title="$3"
    output="$4"
    shift 4

    if [ "$#" -gt "0" ]; then
        legend=( "$@" )
    else
        legend=( $(files_to_machines $filter) )
    fi

    echo_filter $filter
    $TOOLS_PATH/csv_compare.py \
        --output_title "Appendix $no. Latency: $title (all platforms)" \
        --output_layout 'lat_all' \
        --output_with_table \
        --legend "${legend[@]}" \
        --output_file "$output.png" \
        $filter
    echo
}

function lat_figures()
{
    filter="$1"
    title="$2"
    figno="$3"
    output="$4"
    shift 4

    if [ "$#" -gt "0" ]; then
        legend=( "$@" )
    else
        legend=( $(files_to_machines $filter) )
    fi

    echo_filter $filter
    layouts=('lat_avg' 'lat_pctls_999' 'lat_pctls_99999')
    title_prefixes=( \
        'Latency' \
        'Latency (99.0% and 99.9% percentiles)' \
        'Latency (99.99% and 99.999% percentiles)')
    for index in "${!layouts[@]}"; do
        layout="${layouts[$index]}"
        title_prefix="${title_prefixes[$index]}"
        printf -v figno_name "%0${N_DIGITS}d" $figno
        $TOOLS_PATH/csv_compare.py \
            --output_title "Figure $figno. $title_prefix: $title" \
            --output_layout "$layout" \
            --output_with_table \
            --legend "${legend[@]}" \
            --output_file "Figure_${figno_name}_$output.png" \
            $filter
        figno=$((figno + 1))
    done
    echo
}

function bw_appendix()
{
    filter="$1"
    no="$2"
    title="$3"
    arg_axis="$4"
    output="$5"
    shift 5

    if [ "$#" -gt 0 ]; then
        legend=( "$@" )
    else
        legend=( $(files_to_machines $filter) )
    fi

    echo_filter $filter
    $TOOLS_PATH/csv_compare.py \
        --output_title "Appendix $no. Bandwidth: $title (all platforms)" \
        --output_layout 'bw' \
        --arg_axis "$arg_axis" \
        --output_with_table \
        --legend "${legend[@]}" \
        --output_file "$output.png" \
        $filter
    echo
}

function bw_figure()
{
    filter="$1"
    title="$2"
    figno="$3"
    arg_axis="$4"
    output="$5"
    shift 5

    if [ "$#" -gt 0 ]; then
        legend=( "$@" )
    else
        legend=( $(files_to_machines $filter) )
    fi

    printf -v figno_name "%0${N_DIGITS}d" $figno

    echo_filter $filter
    $TOOLS_PATH/csv_compare.py \
        --output_title "Figure $figno. $title" \
        --output_layout 'bw' \
        --arg_axis "$arg_axis" \
        --output_with_table \
        --legend "${legend[@]}" \
        --output_file "Figure_${figno_name}_$output.png" \
        $filter
    echo
}

TOOLS_PATH=$(pwd)

# prepare a report directory
TIMESTAMP=$(date +%y-%m-%d-%H%M%S)
STAMP=${STAMP:-$TIMESTAMP}
REPORT_DIR=report_$STAMP
rm -rdf $REPORT_DIR
mkdir $REPORT_DIR
cd $REPORT_DIR

echo "Output directory: $REPORT_DIR"
echo
echo 'READ LAT'

echo '- compare all machines ib_read_lat'
lat_appendix \
    "$DATA_PATH/READ/*/DRAM/*/CSV/ib*lat*" \
    'B1' 'ib_read_lat from DRAM' \
    'Appendix_B1_ib_read_lat'

echo '- compare all machines rpma_read() from DRAM'
lat_appendix \
    "$DATA_PATH/READ/*/DRAM/*/CSV/rpma*lat*" \
    'B2' 'rpma_read() from DRAM' \
    'Appendix_B2_rpma_read_lat_DRAM'

echo '- compare all machines rpma_read() from PMEM'
lat_appendix \
    "$DATA_PATH/READ/*/PMEM/*/CSV/rpma*lat*" \
    'B3' 'rpma_read() from PMEM' \
    'Appendix_B3_rpma_read_lat_PMEM'

echo '- ib_read_lat vs rpma_read() from DRAM vs rpma_read() from PMEM'
if [ -z "$READ_LAT_MACHINE" ]; then
	echo "SKIP: READ_LAT_MACHINE not set"
    echo
else
    lat_figures \
        "$DATA_PATH/READ/MACHINE_$READ_LAT_MACHINE/DRAM/*/CSV/*lat* $DATA_PATH/READ/MACHINE_$READ_LAT_MACHINE/PMEM/*/CSV/*lat*" \
        'rpma_read() vs ib_read_lat' \
        '2' 'rpma_read_lat_vs_ib' \
        'ib_read_lat from DRAM' 'rpma_read() from DRAM' 'rpma_read() from PMEM'
fi

echo "READ BW(BS)"

echo "- compare all machines ib_read_bw"
bw_appendix \
    "$DATA_PATH/READ/*/DRAM/*/CSV/ib*bw-bs*" \
    'C1' 'ib_read_bw from DRAM' \
    'bs' \
    'Appendix_C1_ib_read_bw_bs'


echo "- compare all machines rpma_read() from DRAM"
bw_appendix \
    "$DATA_PATH/READ/*/DRAM/*/CSV/rpma*bw-bs*" \
    'C2' 'rpma_read() from DRAM' \
    'bs' \
    'Appendix_C2_rpma_read_bw_bs_dram'

echo "- compare all machines rpma_read() from PMEM"
bw_appendix \
    "$DATA_PATH/READ/*/PMEM/*/CSV/rpma*bw-bs*" \
    'C3' 'rpma_read() from PMEM' \
    'bs' \
    'Appendix_C3_rpma_read_bw_bs_pmem'

echo "- ib_read_bw vs rpma_read() from DRAM vs rpma_read() from PMEM"
if [ -z "$READ_BW_MACHINE" ]; then
	echo "SKIP: READ_BW_MACHINE not set"
    echo
else
    bw_figure \
        "$DATA_PATH/READ/MACHINE_$READ_BW_MACHINE/DRAM/*/CSV/*bw-bs* $DATA_PATH/READ/MACHINE_$READ_BW_MACHINE/PMEM/*/CSV/*bw-bs*" \
        'Bandwidth: rpma_read() vs ib_read_bw' \
        '5' \
        'bs' \
        'rpma_read_bw_bs_vs_ib' \
        'ib_read_bw from DRAM' 'rpma_read() from DRAM' 'rpma_read() from PMEM'
fi

echo "READ BW(TH)"

echo "- compare all machines ib_read_bw"
bw_appendix \
    "$DATA_PATH/READ/*/DRAM/*/CSV/ib*bw-th*" \
    'D1' 'ib_read_bw from DRAM' \
    'threads' \
    'Appendix_D1_ib_read_bw_th'

echo "- compare all machines rpma_read() from DRAM"
bw_appendix \
    "$DATA_PATH/READ/*/DRAM/*/CSV/rpma*bw-th*" \
    'D2' 'rpma_read() from DRAM' \
    'threads' \
    'Appendix_D2_rpma_read_bw_th_dram'

echo "- compare all machines rpma_read() from PMEM"
bw_appendix \
    "$DATA_PATH/READ/*/PMEM/*/CSV/rpma*bw-th*" \
    'D3' 'rpma_read() from PMEM' \
    'threads' \
    'Appendix_D3_rpma_read_bw_th_pmem'

echo "- ib_read_bw vs rpma_read() from DRAM vs rpma_read() from PMEM"
if [ -z "$READ_BW_MACHINE" ]; then
	echo "SKIP: READ_BW_MACHINE not set"
    echo
else
    bw_figure \
        "$DATA_PATH/READ/MACHINE_$READ_BW_MACHINE/DRAM/*/CSV/*bw-th* $DATA_PATH/READ/MACHINE_$READ_BW_MACHINE/PMEM/*/CSV/*bw-th*" \
        'Bandwidth: rpma_read() vs ib_read_bw' \
        '6' \
        'threads' \
        'rpma_read_bw_th_vs_ib' \
        'ib_read_bw' 'rpma_read() from DRAM' 'rpma_read() from PMEM'
fi

echo 'WRITE LAT'

echo '- compare all machines rpma_write() + rpma_flush() to DRAM'
lat_appendix \
    "$DATA_PATH/WRITE/*/DRAM/*/CSV/rpma*lat*" \
    'E1' 'rpma_write() + rpma_flush() to DRAM' \
    'Appendix_E1_rpma_write_flush_lat_DRAM'

echo '- compare all machines rpma_write() + rpma_flush() to PMEM'
lat_appendix \
    "$DATA_PATH/WRITE/*/PMEM/*/CSV/rpma*lat*" \
    'E2' 'rpma_write() + rpma_flush() to PMEM' \
    'Appendix_E2_rpma_write_flush_lat_PMEM'

echo '- rpma_write() + rpma_flush() to DRAM vs to PMEM'
if [ -z "$WRITE_LAT_MACHINE" ]; then
	echo "SKIP: WRITE_LAT_MACHINE not set"
    echo
else
    lat_figures \
        "$DATA_PATH/WRITE/MACHINE_$WRITE_LAT_MACHINE/DRAM/*/CSV/*lat* $DATA_PATH/WRITE/MACHINE_$WRITE_LAT_MACHINE/PMEM/*/CSV/*lat*" \
        'rpma_write() + rpma_flush()' \
        '7' 'rpma_write_flush_lat' \
        'to DRAM' 'to PMEM'
fi

echo 'WRITE BW(BS)'

echo '- compare all machines rpma_write() + rpma_flush() to DRAM'
bw_appendix \
    "$DATA_PATH/WRITE/*/DRAM/*/CSV/rpma*bw-bs*" \
    'F1' 'rpma_write() + rpma_flush() to DRAM' \
    'bs' \
    'Appendix_F1_rpma_write_flush_bw_bs_DRAM'

echo '- compare all machines rpma_write() + rpma_flush() to PMEM'
bw_appendix \
    "$DATA_PATH/WRITE/*/PMEM/*/CSV/rpma*bw-bs*" \
    'F2' 'rpma_write() + rpma_flush() to PMEM' \
    'bs' \
    'Appendix_F2_rpma_write_flush_bw_bs_PMEM'

echo '- rpma_write() + rpma_flush() to DRAM vs to PMEM'
if [ -z "$WRITE_BW_MACHINE" ]; then
	echo "SKIP: WRITE_BW_MACHINE not set"
    echo
else
    bw_figure \
        "$DATA_PATH/WRITE/MACHINE_$WRITE_BW_MACHINE/DRAM/*/CSV/*bw-bs* $DATA_PATH/WRITE/MACHINE_$WRITE_BW_MACHINE/PMEM/*/CSV/*bw-bs*" \
        'Bandwidth: rpma_write() + rpma_flush()' \
        '10' \
        'bs' \
        'rpma_write_flush_bw_bs' \
        'to DRAM' 'to PMEM'
fi

echo 'WRITE BW(TH)'

echo '- compare all machines rpma_write() + rpma_flush() to DRAM'
bw_appendix \
    "$DATA_PATH/WRITE/*/DRAM/*/CSV/rpma*bw-th*" \
    'G1' 'rpma_write() + rpma_flush() to DRAM' \
    'threads' \
    'Appendix_G1_rpma_write_flush_bw_th_DRAM'

echo '- compare all machines rpma_write() + rpma_flush() to PMEM'
bw_appendix \
    "$DATA_PATH/WRITE/*/PMEM/*/CSV/rpma*bw-th*" \
    'G2' 'rpma_write() + rpma_flush() to PMEM' \
    'threads' \
    'Appendix_G2_rpma_write_flush_bw_th_PMEM'

echo '- rpma_write() + rpma_flush() to DRAM vs to PMEM'
if [ -z "$WRITE_BW_MACHINE" ]; then
	echo "SKIP: WRITE_BW_MACHINE not set"
    echo
else
    bw_figure \
        "$DATA_PATH/WRITE/MACHINE_$WRITE_BW_MACHINE/DRAM/*/CSV/*bw-th* $DATA_PATH/WRITE/MACHINE_$WRITE_BW_MACHINE/PMEM/*/CSV/*bw-th*" \
        'Bandwidth: rpma_write() + rpma_flush()' \
        '11' \
        'threads' \
        'rpma_write_flush_bw_th' \
        'to DRAM' 'to PMEM'
fi
