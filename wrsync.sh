#!/bin/bash

# TODO: folder end slash

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


# init two-way sync, no delete, 
function init-sync {
    echo init-sync
    rsync -azus --cvs-exclude "${REMOTEHOST}:${REMOTEPATH}" "${LOCALPATH}" 2>>"${RSYNCLOG}"
    if [ $? -gt 0 ]
    then
        echo "Error while syncing from ${REMOTEHOST}:${REMOTEPATH}"  2>>"${RSYNCLOG}"
        exit 1
    fi
    rsync -azus --cvs-exclude "${LOCALPATH}" "${REMOTEHOST}:${REMOTEPATH}" 2>>"${RSYNCLOG}"
    if [ $? -gt 0 ]
    then
        echo "Error while syncing to ${REMOTEHOST}:${REMOTEPATH}"  2>>"${RSYNCLOG}"
        exit 1
    fi
}

function sync-lastsync {
    echo sync-lastsync >&2
    #TODO: exit on rsync failure
    rsync -azs --itemize-changes "${LASTSYNCFILE}" "${REMOTEHOST}:${REMOTECONF}${LASTSYNCFILENAME}" | wc -l
}

function sync {
    echo sync
    touch "${NEWSYNCFILE}"
    if [ -f "${LASTSYNCFILE}" ]
    then
        NEWSYNC=`sync-lastsync`
        echo $NEWSYNC
        if [ "${NEWSYNC}" = "0" ]
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
    ssh "$REMOTEHOST" 'find '"${REMOTEPATH}"' -not -newermm '"${REMOTECONF}${LASTSYNCFILENAME}"\
        '-or -not -newercc '"${REMOTECONF}${LASTSYNCFILENAME}"\
        ' -not -type d' | sort | sed 's|'"$REMOTEPATH"'|- |' > "${FILTERFILE}"
    find "$LOCALPATH" -not -newermm "${LASTSYNCFILE}" \
        -or -not -newercc "${LASTSYNCFILE}" \
        -not -type d | sort | sed 's|'"$LOCALPATH"'|R |' >> "${FILTERFILE}"
    echo "P *" >> "${FILTERFILE}"
}

function sync-from {
    echo sync-from
    LISTFROM=`rsync -azus --itemize-changes --delete --cvs-exclude --filter=". ${CONFDIR}/filter" \
        "${REMOTEHOST}:${REMOTEPATH}" "${LOCALPATH}" 2>>"$RSYNCLOG"`
    if [ -n "${LISTFROM}" ];
    then
        notify-send "${LISTFROM}"
    fi
}

function sync-to {
    echo sync-to
    LISTTO=`rsync -azus --itemize-changes --delete --cvs-exclude "${LOCALPATH}" "${REMOTEHOST}:${REMOTEPATH}" \
        2>>"$RSYNCLOG"`
    if [ -n "${LISTTO}" ];
    then
        notify-send "${LISTTO}"
    fi
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
