
SRC=""
DEST="/media/kairav/PROJECTS/dev/"

.PHONY: backup devtodrive

all:
	backup

backup:
	python ~/.local/share/config-backup/config_backup.py 

drive:
	fpsync -n 8 \
  -o "-lptgoD -vhW --info=progress2 --exclude-from=/tmp/rsync_excludes.txt" \
  $(SRC) \
  $(DEST)
