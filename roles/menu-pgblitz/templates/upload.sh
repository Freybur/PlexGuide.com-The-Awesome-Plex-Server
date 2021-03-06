{% raw %}
#!/bin/bash
##
# GitHub:   https://github.com/Admin9705/PlexGuide.com-The-Awesome-Plex-Server
# Author:   Admin9705 & FlickerRate & Bryde ツ & PhysK
# URL:      https://plexguide.com
#
# PlexGuide Copyright (C) 2018 PlexGuide.com
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
#################################################################################
downloadpath=$(cat /var/plexguide/server.hd.path)
IFS=$'\n'

FILE=$1
GDSA=$2
echo "[PGBlitz] [Upload] Upload started for $FILE using $GDSA" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh

STARTTIME=`date +%s`
FILESTER=`echo $FILE | sed 's/\'$downloadpath'\/move//g'`
FILEBASE=`basename $FILE`
FILEDIR=`dirname $FILE | sed 's/\'$downloadpath'\/move//g'`

JSONFILE=/opt/appdata/pgblitz/json/$FILEBASE.json
echo "With /mnt/move Removed - $FILESTER"
echo "Filename - $FILEBASE"
echo "File DIR - $FILEDIR"

mkdir -p $downloadpath/pgblitz/$GDSA
echo "[PGBlitz] [Upload] Moving $FILE to GDSA folder: $GDSA" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh

# add to file lock to stop another process being spawned while file is moving
echo "lock" > $FILE.lck

#get Human readable filesize
HRFILESIZE=`ls -lsah $FILE | awk '{print $6}'`

#create json file for PGbliz GUI
echo "{\"filedir\": \"$FILEDIR\",\"filebase\": \"$FILEBASE\",\"filesize\": \"$HRFILESIZE\", \"status\": \"moving\",\"gdsa\": \"$GDSA\"}" > $JSONFILE

#move file to pgblitz folder
mkdir -p $downloadpath/pgblitz/$GDSA$FILEDIR/
mv $FILE $downloadpath/pgblitz/$GDSA$FILEDIR/$FILEBASE
sleep 5

echo "[PGBlitz] [Upload] $FILE Moved" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh
echo "[PGBlitz] [Upload] $FILE Moved"

#remove file lock
rm -f $FILE.lck

#if using encrypted add -E to the end of $GDSA
if [ -e /opt/appdata/pgblitz/vars/encrypted ]; then
    REMOTE=${GDSA}C
else
    REMOTE=$GDSA
fi

echo "[PGBlitz] [Upload] Uploading $FILE to $REMOTE" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh
LOGFILE=/opt/appdata/pgblitz/logs/$FILEBASE.log

#create and chmod the log file so that webui can read it
touch $LOGFILE
chmod 777 $LOGFILE

#update json file for PGBlitz GUI
echo "{\"filedir\": \"$FILEDIR\",\"filebase\": \"$FILEBASE\",\"filesize\": \"$HRFILESIZE\",\"status\": \"uploading\",\"logfile\": \"/logs/$FILEBASE.log\",\"gdsa\": \"$GDSA\"}" > $JSONFILE
echo "[PGBlitz] [Upload] Starting Upload"
rclone moveto --tpslimit 6 --checkers=20 \
      --config /root/.config/rclone/rclone.conf \
      --transfers=8 \
      --log-file=$LOGFILE --log-level INFO --stats 2s \
      --drive-chunk-size=32M \
      "$downloadpath/pgblitz/$GDSA$FILEDIR/$FILEBASE" "$REMOTE:$FILEDIR/$FILEBASE"

#update json file for PGBlitz GUI
echo "{\"filedir\": \"$FILEDIR\",\"filebase\": \"$FILEBASE\",\"status\": \"vfs\",\"gdsa\": \"$GDSA\"}" > $JSONFILE

#rm -f $FILEDIR/folder.lck
#waiting for file to become avalible from remote and then vfs/forget it
rclone rc vfs/forget file="$FILEDIR/$FILEBASE"
echo "[PGBlitz] [Upload] vfs/forgot $FILEDIR/$FILEBASE" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh

ENDTIME=`date +%s`
#update json file for PGBlitz GUI
echo "{\"filedir\": \"$FILEDIR\",\"filebase\": \"$FILEBASE\",\"filesize\": \"$HRFILESIZE\",\"status\": \"done\",\"gdsa\": \"$GDSA\",\"starttime\": \"$STARTTIME\",\"endtime\": \"$ENDTIME\"}" > $JSONFILE

#de-dupe just in case (does not work)
#if [ -e /opt/appdata/pgblitz/vars/encrypted ]; then
#    rclone dedupe tcrypt:$FILEDIR --dedupe-mode newest
#else
#    rclone dedupe tdrive:$FILEDIR --dedupe-mode newest
#fi

echo "[PGBlitz] [Upload] Upload complete for $FILE, Cleaning up" > /var/plexguide/pg.log && bash /opt/plexguide/roles/log/log.sh
#cleanup
rm -f $LOGFILE
rm -f /opt/appdata/pgblitz/pid/$FILEBASE.trans
find "/mnt/move/" -mindepth 1 -type d -empty -delete
find "/mnt/pgblitz/" -mindepth 2 -type d -empty -delete
sleep 60
rm -f $JSONFILE
{% endraw %}