ARGS :=
SRC :=
DEST := /media/kairav/PROJECTS/dev/

.PHONY: all backup add drive

all: backup

backup:
	python ~/.local/share/config-backup/config_backup.py

add:
	python ~/.local/share/config-backup/config_backup.py add $(ARGS)

drive:
	fpsync -n 8 \
		-o "-lptgoD -vhW --info=progress2 --exclude-from=/tmp/rsync_excludes.txt" \
		"$(SRC)" \
		"$(DEST)"
