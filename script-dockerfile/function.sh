#!/bin/bash
set -x
DATE="$(date +"%Y-%m-%d")"
FILENAME="$DB_NAME-$DATE"
BACKUP_DIR="/new_backup"
#BACKUP_TYPE="${BACKUP_TYPE}"
#PGUSER="${PGUSER}"
#MYSQL_USER="${MYSQL_USER}"
#MYSQL_PWD="${MYSQL_PWD}"
#DB_NAME="${DB_NAME}"
#HOST="${HOST}"
#BACKUP_STORAGE_URL="${BACKUP_STORAGE_URL}"
#SLACK_URL=
#CLUSTER="${CLUSTER}"

# create a directory for backup
mkdir $BACKUP_DIR
chmod 0777 $BACKUP_DIR
cd $BACKUP_DIR

# slack notification when backup fails
slack_fail() {
   curl -H "Content-type:application/json" \
   -X POST -d \
   '{
      "attachments" : [
        {
          "color" : "#ff2200",
          "fields" : [
            {
               "title" : ":red_circle: '"[!!ERROR!!] Failed to create backup"'",
               "value" : "Type: '"*$1*"'",
               "short" : false
            },
            {
               "value" : "Database: '"*$2*"'",
               "short" : false
            },
          ]
        }
      ]
    }
   ' "$SLACK_URL"
}
# slack notification when backup completed successfully
slack_done() {
   curl -H "Content-type:application/json" \
   -X POST -d \
   '{
      "attachments" : [
        {
          "color" : "#00ff0c",
          "fields" : [
            {
               "title" : ":tada: Backup completed successfully",
               "value" : "Name: '"*$1*"'",
               "short" : false
            },
            {
               "value" : "Type: '"*$2*"'",
               "short" : false
            },
            {
               "value" : "Uploaded to: s3'"`echo $3 | cut -c 5-`"'",
               "short" : false
            },
          ]
        }
      ]
    }
   ' "$SLACK_URL"
}

# check backup variable
if [[ ${BACKUP_TYPE} == "" ]]; then
  slack_fail "Missing BACKUP_TYPE env variable"
  exit 1
fi

# copy backup to AWS s3 bucket
aws_s3_cp() {
  aws s3 cp "$1" "$BACKUP_STORAGE_URL/$CLUSTER/"$2"/"
}

# create mysql backup
mysql() {
  if mysqldump --user="$MYSQL_USER" --password="$MYSQL_PWD" --host="$HOST" --databases "$DB_NAME" > "$FILENAME.sql" && gzip "$FILENAME.sql" && aws_s3_cp "$FILENAME.sql.gz" "MYSQL"; then
  slack_done "$FILENAME.sql.gz" "$BACKUP_TYPE" "$BACKUP_STORAGE_URL/$CLUSTER/MYSQL/"
  else
  slack_fail "$BACKUP_TYPE" "$DB_NAME"
  fi
}
# create postgres backup
postgres() {
  if pg_dump --username="$PGUSER" --host="$HOST" "$DB_NAME" -w -O -Fc > "$FILENAME.dump" && gzip "$FILENAME.dump" && aws_s3_cp "$FILENAME.dump.gz" "POSTGRES"; then
  slack_done "$FILENAME.dump.gz" "$BACKUP_TYPE" "$BACKUP_STORAGE_URL/$CLUSTER/POSTGRES/"
  else
  slack_fail "$BACKUP_TYPE" "$DB_NAME"
  fi
}

# check what type is backup variable and what type of backup to perform
if [ "$BACKUP_TYPE" = MYSQL ]; then
  mysql
elif [ "$BACKUP_TYPE" = POSTGRES ]; then
  postgres
fi

# clear backup directory
clear() {
rm -r "$BACKUP_DIR"
}
clear