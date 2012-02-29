#!/bin/bash

# TODO: folder end slash

#get options
# while getopts d:D: name
# do
#     case $name in
#         d)    CONFDIR="$OPTARG";;
#         D)    MULTICONFDIR="$OPTARG";;
#         ?)    printf "Usage: %s: [-d dir | -D dir] \n" $0
#             exit 2;;
#     esac
# done

function set-defaults {
#DEFAULTS
#    DEFAULTCONFDIR="~/.wrsync"
    CONFFILENAME="wrsync.conf"
    LASTSYNCFILENAME="lastsync"
    NEWSYNCFILENAME="newsync"
    RSYNCLOGNAME="rsync.log"
    FILTERFILENAME="filter"

    CONFFILE=${CONFDIR}${CONFFILENAME}
    LASTSYNCFILE=${CONFDIR}${LASTSYNCFILENAME}
    NEWSYNCFILE=${CONFDIR}${NEWSYNCFILENAME}
    RSYNCLOG=${CONFDIR}${RSYNCLOGNAME}
    FILTERFILE=${CONFDIR}${FILTERFILENAME}
}


# function reset {
#     echo reset
#     CONFDIR=
#     LOCALPATH=
#     REMOTEHOST=
#     REMOTEPATH=
#     REMOTECONF=
#     NEWSYNC=
# }

# init two-way sync, no delete, 
function init-sync {
    echo init-sync
    rsync -azus --cvs-exclude "${REMOTEHOST}:${REMOTEPATH}" "${LOCALPATH}" 2>>"${RSYNCLOG}"
    if [ $? -gt 0 ]
    then
        exit 1
    fi
    rsync -azus --cvs-exclude "${LOCALPATH}" "${REMOTEHOST}:${REMOTEPATH}" 2>>"${RSYNCLOG}"
    if [ $? -gt 0 ]
    then
        exit 1
    fi
}

function sync-lastsync {
    echo sync-lastsync
    #TODO: exit on rsync failure
    rsync -azs --itemize-changes "${LASTSYNCFILE}" "${REMOTEHOST}:${REMOTECONF}${LASTSYNCFILENAME}" | wc -l
}

# # sync for every subdir of $MULTICONFDIR
# function sync-all {
#     echo sync-all
#     if [ ! -d "${MULTICONFDIR}" ]
#     then
#         echo "No configuration directory: ${MULTICONFDIR}"
#         exit 1
#     fi
#     for confdir in `find $MULTICONFDIR -type d`;
#     do
#         CONFDIR=$confdir
#         sync
#         reset
#     done
# }

function sync {
    echo sync
    touch "${NEWSYNCFILE}"
    if [ -f "${LASTSYNCFILE}" ]
    then
        NEWSYNC=`sync-lastsync`
        if [ "${NEWSYNC}" == "0" ]
        then
            sync-to
        else
            prepare-filter
            sync-from
            sync-to
        fi
    else
        init-sync
    fi
    cp -pf "${NEWSYNCFILE}" "${LASTSYNCFILE}"
    rm -f "${NEWSYNCFILE}"
    sync-lastsync
}

function prepare-filter {
    echo prepare-filter
    # find files in $LOCALPATH not modified after $LASTSYNCFILE
    ssh "$REMOTEHOST" 'find '"${REMOTEPATH}"' -not -newer '"${REMOTECONF}${LASTSYNCFILENAME}"\
        ' -not -type d' | sort | sed 's|'"$REMOTEPATH"'|- |' > "${FILTERFILE}"
    find "$LOCALPATH" -not -newer "${LASTSYNCFILE}" \
        -not -type d | sort | sed 's|'"$LOCALPATH"'|R |' >> "${FILTERFILE}"
    echo "P *" >> "${FILTERFILE}"
}

function sync-from {
    echo sync-from
    rsync -azus --delete --cvs-exclude --filter=". ${CONFDIR}/filter" \
        "${REMOTEHOST}:${REMOTEPATH}" "${LOCALPATH}" 2>>"$RSYNCLOG"
}

function sync-to {
    echo sync-to
    rsync -azus --delete --cvs-exclude "${LOCALPATH}" "${REMOTEHOST}:${REMOTEPATH}" 2>>"$RSYNCLOG"
}

# program main
CONFDIR=$1
if [ -d "${CONFDIR}" ]
then
    set-defaults
    if [ -f "${CONFFILE}" ]
    then
        #$LOCALPATH $REMOTEHOST $REMOTEPATH $REMOTECONF
        . "${CONFFILE}"
    else
        echo "No configuration file ${CONFDIR}/${CONFFILENAME}"
        exit 1
    fi
    sync
else
    echo "No configuration directory: ${CONFDIR}"
    exit 1
fi

exit 0
