#!/bin/bash
# script for preparing the folder structure necessary to
# feed the islandora batch import module (https://github.com/Islandora/islandora_book_batch)
# It expects a folder of tif files that are in sequence like pages of a book:
# (e.g MYBOOK_001.tif, .. ,MYBOOK_345.tif) and it will output the structure as required by the module

if [ -z "$1" ]
  then
    echo "Specify the folder of the tif images"
    echo "e.g. ./script.sh ./tif_folder book_name"
    exit
fi

if [ -z "$2" ]
  then
    echo "Specify the book name"
    echo "e.g. ./script.sh ./tif_folder book_name"
    exit
fi

# directory of tif files
DIR="$1"

# book name
BOOK_NAME="$2"

#create new book = folder
mkdir -p "$DIR/$BOOK_NAME"

# Index for creating folders 1..n
index=0;

cd "$DIR"

# Find all files and folders in the current directory, sort them and iterate through them
find *.tif -maxdepth 1 -type f | sort | while IFS= read -r file; do

	#flag to check if file has been moved
	moved=0;

	# increment index
	((index++))

	#create new folder
	TARGET="./$BOOK_NAME/$index"
    mkdir -p "$TARGET"	

	# The moved will be 0 until the file is moved
    while [ $moved -eq 0 ]; do
    	
    	# If the directory has no files
		if find "$TARGET" -maxdepth 0 -empty | read; 
		then 
		  # Copy the current file to $target and increment the moved.
		  cp -v "$file" "$TARGET/OBJ.tif" && moved=1; 
		else
		  # Uncomment the line below for debugging 
		  # echo "Directory not empty: $(find "$target" -mindepth 1)"

		  # Wait for one second. This avoids spamming 
		  # the system with multiple requests.
		  sleep 1; 
		fi;
    done;
done

echo -e "\nFolder structure completed..\n"
zip -r $BOOK_NAME.zip $BOOK_NAME
echo -e "Archive completed..\n"
echo -e "Done.\n"
exit 0
