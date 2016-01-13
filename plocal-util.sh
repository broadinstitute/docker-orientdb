#!/bin/sh

# This script can be used to perform the following utility operations on a PLOCAL
#  OrientDB
#  - backup using builtin BACKUP command
#  - restore using builtin RESTORE command
#  - export using the builtin EXPORT command
#  - import using the builtin IMPORT command (note: import datafile must have been
#     created using the EXPORT

# Usage:
#
#  {backup|restore|export|import} -d <dbname> 

#  -r (remove db if exists for restore)
#  -c (create db if does not exist for import)
#  -d <dbname>
#  -u <dbusername> (default: admin)
#  -p <dbpassword> (default: admin)
#  -f <full path of backup|export file> (will be used for either backup|export 
#       or restore|import
#      (default for backup/export {dbname}-backup-[YYYYMMDD-HHMMSS].zip|{dbname}-export-[YYYYMMDD-HHMMSS].gz
#      (default for restore/import {dbname}-backup.zip|{dbname}-export.gz

# Assumptions
#
#  Database will be a PLOCAL database (remote database not supported)
#  Restore will create a PLOCAL PHYSICAL database (not MEMORY database)
#  

# Program will exit upon any error and may leave things in an intermediate state.
# It will not clean up aborted backup/export files
# It will not DROP aborted restore/import databases

# It will fail if database already exists when running restore

# Vars
DBPATH="/opt/orientdb/databases"
BACKUPPATH="/opt/orientdb/backup"
CONSOLE="/opt/orientdb/bin/console.sh"
TSTAMP=`date -u +"%Y%m%d-%H%M%S"`

# directory where command templates are stored.  will be used to build ultimate
#   SQL script
TEMPLATE_DIR="/usr/local/lib/orientdb"

# TEMPLATES
CONN="${TEMPLATE_DIR}/connect.sql"
CREATE="${TEMPLATE_DIR}/create.sql"
BACKUP="${TEMPLATE_DIR}/backup.sql"
RESTORE="${TEMPLATE_DIR}/restore.sql"
IMPORT="${TEMPLATE_DIR}/import.sql"
EXPORT="${TEMPLATE_DIR}/export.sql"
DROP="${TEMPLATE_DIR}/drop.sql"
DISC="${TEMPLATE_DIR}/disconnect.sql"
START="${TEMPLATE_DIR}/start.sql"
LIST="${TEMPLATE_DIR}/list.sql"
END="${TEMPLATE_DIR}/end.sql"

progname=`basename $0`

# default values for args
OPT_u="admin"
OPT_p="admin"
OPT_d=""
OPT_r=0
OPT_i=0
PID=$$

usage() {
   echo
   echo "Usage: $progname -d <dbname> [-r][-c] [-u <dbusername>] [-p <dbpassword>] [-f <full-path-backup-file>] [-x <backup|restore|export|import>] "
   echo 
   echo " <dbname>: name of database to run against"
   echo " -r: remove database if it exists for restore"
   echo " -c: Create database for import"
   echo " -x <command-to-run> "
   echo " <dbusername>, <dbpassword>: database username/password (default admin/admin)"
   echo " <full-path-backup-file>: full pathname to write backup/export to or read from for import/restore"
   echo "   Default for backup: <dbname>-backup-YYYYMMDD-HHMMSS.zip"
   echo "   Default for export: <dbname>-export-YYYYMMDD-HHMMSS.gz"
   echo "   Default for restore:: <dbname>-backup.zip"
   echo "   Default for import:: <dbname>-export.gz"
   echo

}

# process getopts
while getopts :d:u:p:f:x:hrc FLAG; do
   case $FLAG in
     d)  OPT_d="$OPTARG"
     ;; 
     f)  OPT_f="$OPTARG"
     ;; 
     h)  usage
        exit 1
     ;;
     i)  OPT_c=1
     ;;
     p)  OPT_p="$OPTARG"
     ;; 
     r)  OPT_r=1
     ;;
     u)  OPT_u="$OPTARG"
     ;; 
     x)  progname="plocal-${OPTARG}"
     ;;
    esac
done

shift $((OPTIND-1)) 

# set rest of line to be passed to SQL command
# restargs="$restargs $*"

# tempfile 
TMPFILE="/root/${progname}-${PID}"

cleanup() {
   rm -f ${TMPFILE}
}

if [ -z "${OPT_d}" ]
then
   echo
   echo "Must specify database name via: -d <dbname> "
   usage
   cleanup
   exit 1
fi

# set output filename to default if not specified
if [ -z "${OPT_f}" ]
then
      case "${progname}" in
      "plocal-backup")
          OPT_f="${OPT_d}-${progname}-${TSTAMP}.zip"
          ;;
      "plocal-export")
          OPT_f="${OPT_d}-${progname}-${TSTAMP}.gz"
          ;;
      "plocal-import")
          OPT_f="${OPT_d}-export.gz"
          ;;
      "plocal-restore")
          OPT_f="${OPT_d}-backup.zip"
          ;;
      esac
fi

# TODO check if critical directories exist 

# exit 0
# based on program name perform operation

case "${progname}" in
   # BACKUP DATABASE
   "plocal-backup")
       #  FIRST CONNECT ; DISCONNECT to see if its available for backup
       cat ${START} ${CONN} ${DISC} | sed -e "s;DBPATH;${DBPATH};g" -e "s;DBNAME;${OPT_d};g" -e "s;DBUSER;${OPT_u};g" -e "s;DBPASSWORD;${OPT_p};g" -e "s;BACKUPPATH;${BACKUPPATH};g" -e "s;BACKUPFILE;${OPT_f};g" > ${TMPFILE}
       if [ -s "${TMPFILE}" ]
       then
          ${CONSOLE} ${TMPFILE}
          retcode=$?
          if [ "$retcode" -ne 0 ]
          then
             #   if failed error - report DB connection failed
             echo "ERROR: Could not connect to database (${OPT_d})! Backup FAILED!"
             cleanup
             exit 2
          fi
       fi 

       #  RUN BACKUP
       cat ${START} ${CONN} ${LIST} ${BACKUP} ${DISC} | sed -e "s;DBPATH;${DBPATH};g" -e "s;DBNAME;${OPT_d};g" -e "s;DBUSER;${OPT_u};g" -e "s;DBPASSWORD;${OPT_p};g" -e "s;BACKUPPATH;${BACKUPPATH};g" -e "s;BACKUPFILE;${OPT_f};g" > ${TMPFILE}
       if [ -s "${TMPFILE}" ]
       then
          ${CONSOLE} ${TMPFILE}
          retcode=$?
          if [ "$retcode" -ne 0 ]
          then
             #   if failed error - report DB backup failed
             echo "ERROR: Backup failed for database: (${OPT_d}). Exitting.."
             cleanup
             exit 2
          fi
       fi
     ;;

   "plocal-restore")
       #  FIRST CONNECT ; DISCONNECT to see if database exists
       cat ${START} ${CONN} ${DISC} | sed -e "s;DBPATH;${DBPATH};g" -e "s;DBNAME;${OPT_d};g" -e "s;DBUSER;${OPT_u};g" -e "s;DBPASSWORD;${OPT_p};g" -e "s;BACKUPPATH;${BACKUPPATH};g" -e "s;BACKUPFILE;${OPT_f};g" > ${TMPFILE}
       if [ -s "${TMPFILE}" ]
       then
          ${CONSOLE} ${TMPFILE}
          retcode=$?
          if [ $retcode -eq 0 ]
          then
             if [ ${OPT_r} -eq 0  ]
             then
                 # DB exists and -r flag was not specified  
                 echo "ERROR: Database (${OPT_d}) exists and -r (drop before restore) flag was not specified.  Aborting restore!!"
                 cleanup
                 exit 2
             else
                # DB exists and -r flag specified to DROP
                # DROP before restore
                cat ${START} ${DROP} | sed -e "s;DBPATH;${DBPATH};g" -e "s;DBNAME;${OPT_d};g" -e "s;DBUSER;${OPT_u};g" -e "s;DBPASSWORD;${OPT_p};g" -e "s;BACKUPPATH;${BACKUPPATH};g" -e "s;BACKUPFILE;${OPT_f};g" > ${TMPFILE}
                if [ -s "${TMPFILE}" ]
                then
                   ${CONSOLE} ${TMPFILE}
                   retcode=$?
                   if [ "$retcode" -ne 0 ]
                   then
                      # DROP DB failed
                      echo "ERROR: Database (${OPT_d}) DROP failed.  Unable to Restore - Exitting"
                      cleanup
                      exit 2
                  fi
                fi
             fi
          fi
       fi 

       # CREATE DATABASE
       cat ${START} ${CREATE} ${DISC} | sed -e "s;DBPATH;${DBPATH};g" -e "s;DBNAME;${OPT_d};g" -e "s;DBUSER;${OPT_u};g" -e "s;DBPASSWORD;${OPT_p};g" -e "s;BACKUPPATH;${BACKUPPATH};g" -e "s;BACKUPFILE;${OPT_f};g" > ${TMPFILE}
       if [ -s "${TMPFILE}" ]
       then
          ${CONSOLE} ${TMPFILE}
          retcode=$?
          if [ "$retcode" -ne 0 ]
          then
             # DB Creation failed
             echo "ERROR: Could NOT create database (${OPT_d}).  Unable to Restore. - Exitting"
             cleanup
             exit 2
          fi
       fi
       
       # CONNECT ; RESTORE ; DISCONNECT ; CONNECT ; DISCONNECT
       cat ${START} ${CONN} ${RESTORE} ${DISC} ${CONN} ${DISC} | sed -e "s;DBPATH;${DBPATH};g" -e "s;DBNAME;${OPT_d};g" -e "s;DBUSER;${OPT_u};g" -e "s;DBPASSWORD;${OPT_p};g" -e "s;BACKUPPATH;${BACKUPPATH};g" -e "s;BACKUPFILE;${OPT_f};g" > ${TMPFILE}
       if [ -s "${TMPFILE}" ]
       then
          ${CONSOLE} ${TMPFILE}
          retcode=$?
          if [ "$retcode" -ne 0 ]
          then
             # Restore failed
             echo "ERROR: Error occurred during RESTORE of database (${OPT_d}). Exitting"
             cleanup
             exit 2
          fi
       fi
     ;;
   "plocal-export")
       #  CONNECT ; DISCONNECT
       #   if failed error reporting db connection failed
       #  CONNECT ; EXPORT {rest of command args}
     ;;
   "plocal-import")
       # CONNECT ; DISCONNECT
       # if failed error unless -c flag (create db)
       #    if -c flag
       #       CREATE ; DISCONNECT
       #       if failed error - reporting unable to create database for import
       #  CONNECT ; IMPORT {rest of command args} ; DISCONNECT
       #   CONNECT ; DISCONNECT
       #     if failed report issue
     ;;
   *)
     usage
     ;;
esac

cleanup
exit 0
