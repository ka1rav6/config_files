# 1- 14 [space ] [name (space separated)] .pdf

from pathlib import Path
FOLDER = "/home/kairav/Desktop"
folder = Path(FOLDER)

for file in folder.iterdir():
    if file.is_file() and file.suffix == ".pdf":
        parts = file.stem.split(" ")
        if len(parts) >= 2:
            number = parts[0]
            new_name = str(number) + ".pdf"
            new_path = folder / new_name
            file.rename(new_path)

print("done")

