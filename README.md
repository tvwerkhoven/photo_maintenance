# About

This is a collection of scripts to maintain and publish photo archives.

# Archive integrity

To prevent bitrot when the filesystem does not take care of this (e.g. on macOS), one can use `par2` to manually create and check integrity.

# Publishing

To publish pictures in lower resolution to the web or phone, this script scans a source directory for pictures with 5 star rating rating in the IPTC header and exports these pictures in lower resolution to a separate directory. I use this to store more pictures on my iPhone, for example.

# One-liners

## Find non-geotags
Recursively find JPEG-files that have no geotag:

    find . -iregex ".*\.\(jp.*g\)" -exec sh -c 'f="{}"; test -z $(jhead "$f" | grep GPS | head -n 1 | cut -f1 -d" ") && echo $f' \;

## Copy gps from one file

Given an image with a GPS / geotag, copy it to other files

    exiftool −overwrite_original_in_place -tagsFromFile SOURCE.JPG -gps:all IMGX*JPG

Using these tags:

    −overwrite_original_in_place ensure all other file parameters are kept identical
    -tagsFromFile               indicate which source file to use
    -gps:all                    indicate which tags to copy

From: https://superuser.com/questions/377431/transfer-exif-gps-info-from-one-image-to-another#377434

## Archive
Manually archive pictures to (external) backup:

    rsync -aNurv --exclude-from=/Users/tim/.rsync/exclude --progress -e ssh  --exclude="iPod Photo Cache" ~/Pictures /Volumes/Photos\ Backup\ 2/

Using these tags:

    -a, --archive               archive mode; equals -rlptgoD (no -H,-A,-X)
    -l, --links                 copy symlinks as symlinks
    -p, --perms                 preserve permissions
    -t, --times                 preserve modification times
    -g, --group                 preserve group
    -o, --owner                 preserve owner (super-user only)
    -N, --crtimes               preserve create times (newness)
    -u, --update                skip files that are newer on the receiver
    -r, --recursive             recurse into directories

