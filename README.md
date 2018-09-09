# About

This is a collection of scripts to maintain and publish photo archives.

# Archive integrity

To prevent bitrot when the filesystem does not take care of this (e.g. on macOS), one can use `par2` to manually create and check integrity.

# Publishing

To publish pictures in lower resolution to the web or phone, this script scans a source directory for pictures with 5 star rating rating in the IPTC header and exports these pictures in lower resolution to a separate directory. I use this to store more pictures on my iPhone, for example.

# One-liners

## Find geotags
Recursively find JPEG-files that have no geotag:

    find . -iregex ".*\.\(jp.*g\)" -exec sh -c 'f="{}"; test -z $(jhead "$f" | grep GPS | head -n 1 | cut -f1 -d" ") && echo $f' \;


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

