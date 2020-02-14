# About

This is a collection of scripts to maintain and publish photo archives.

# Archive integrity

To prevent bitrot when the filesystem does not take care of this (e.g. on macOS), one can use `par2` to manually create and check integrity.

# Publishing

To publish pictures in lower resolution to the web or phone, this script scans a source directory for pictures with 5 star rating rating in the IPTC header and exports these pictures in lower resolution to a separate directory. I use this to store more pictures on my iPhone, for example.

# Metadata in videos (geotag & keywords)

Need to preserve geotag and keywords in videos for iOS

## Geotag

Same question, no answer:

    https://superuser.com/questions/1323368/exiftools-tagsfromfile-does-not-help-recover-all-metadata-iphone

Not possible with exiftool:

    http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,5977.0.html
    http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=5631.0

ffmpeg geotag is not recognized by iOS:

    https://trac.ffmpeg.org/ticket/4209

Workaround using mp4extract:

    ffmpeg -i source.mov converted.mp4
    mp4extract moov/meta source.mov source-metadata
    mp4edit --insert moov:source-metadata converted.mp4 converted-withmeta.mp4

Source: https://trac.ffmpeg.org/ticket/6193

## Geotag new videos

TODO:
1. Take existing moov/meta with geotag from iPhone video using mp4extract
2. Get geotag from surrounding (by timestamp) images via exiftool -g
2. Update GPS/datetime data in atom file
3. Re-apply to new video file

## Video keywords

Not working:
- Via Photos, then AirDrop
- Via Photos, then export as original
- Via Photos, then export
- Via Photos, then sync with iPhone
- Via Bridge, then Rollit
- Via Exiftool, with IPTC:Keywords, then Rollit
- Via Exiftool, with quicktime:keywords, then Rollit

TODO: no idea

## PNG timestamps

TODO: keep original metadata (e.g. oplichter marktplaats)

## Picture keywords

Use directory name to add IPTC keywords to picture files

    gfind . -maxdepth 1 -type d | tail -n +2  | while read outdir; do
        # Split dirname in keywords, build exiftool command like:
        # exiftool -IPTC:Keywords="20190930 vakantie vianden luxemburg" -IPTC:Keywords=vakantie -IPTC:Keywords=vianden -IPTC:Keywords=luxemburg
        # Keywords always lowercase to reduce # of unique ones
        outdir=$(basename ${outdir} | tr '[:upper:]' '[:lower:]')
        # Start with full dirname as keyword (to search full string), use as array
        exiftags=()
        exiftags+="-IPTC:Keywords+=${outdir}"
        # Skip date (=first space-separated word) in separate keywords, then add the rest if length is more than 2 letters
        outdirkeywords=${outdir#* }
        # use ${=outdirkeywords} for zsh, see https://scriptingosx.com/2019/08/moving-to-zsh-part-8-scripting-zsh/
        for thiskeyword in ${=outdirkeywords}; do 
            if [ $(echo $thiskeyword | wc -c) -gt 3 ]; then
                exiftags+="-IPTC:Keywords+=${thiskeyword}"
            fi
        done
        # Add keywords, update timestamp, do not store backups (i.e. _original)
        exiftool -overwrite_original ${exiftags} $imgfile "$outdir"
        jhead -ft ${outdir}/*
    done

# One-liners

## Find non-geotags
Recursively find JPEG-files that have no geotag:

    find . -iregex ".*\.\(jp.*g\)" -exec sh -c 'f="{}"; test -z $(jhead "$f" | grep GPS | head -n 1 | cut -f1 -d" ") && echo $f' \;

## Geotag files from other photos

I have a non-GPS camera to take proper pictures in addition to my smartphone camera. One drawback is that this camera does not geotag my pictures. A solution to this is using the smartphone pictures as reference. exiftool can be used to automate this.

Method:

1. Ideally: when taking non-geotaggedpictures, also take a few geotagged pictures to serve as waypoints
2. Create GPX file from geotagged pictures
3. Use GPX file to tag non-geotagged pictures, interpolating where necessary

N.B.

- Personal note: when using (Guru Maps) GPS tracks, do not use manually waypoints - time might be off (delete manually from GPX)
- EXIF does not store timezone, therefore set computer clock to country where pictures were taken OR apply `-geosync` offset as (computer time zone) - (picture timezone), i.e. GMT+1 - GMT+2 = `-geosync=-1:00:00`
- If there was no movement in between geotracks (i.e. at home/hotel), use longer `GeoMaxIntSecs` to allow broader interpolation.

Generate GPX:

    exiftool -if '$gpsdatetime' -fileOrder gpsdatetime -p /Users/tim/Pictures/maintenance/gpx.fmt -d %Y-%m-%dT%H:%M:%SZ *JPG > output.gpx

Apply GPX, only where none applied yet, repair timestamp after update:

    exiftool -if 'not $gpsdatetime' -api GeoMaxIntSecs=18000 -geotag output.gpx *JPG
    jhead -ft *JPG


Source: https://www.sno.phy.queensu.ca/~phil/exiftool/geotag.html#Inverse

## Copy gps from one file

Given an image with a GPS / geotag, copy it to other files

    exiftool −overwrite_original_in_place -tagsFromFile SOURCE.JPG -gps:all IMGX*JPG

Using these tags:

    −overwrite_original_in_place ensure all other file parameters are kept identical
    -tagsFromFile               indicate which source file to use
    -gps:all                    indicate which tags to copy

From: https://superuser.com/questions/377431/transfer-exif-gps-info-from-one-image-to-another#377434

## Number files based on date

    counter=0;
    for f in $(ls -tr *); do
      counter=$(($counter+1))
      numf=$(printf "%03d-$f\n" $counter)
      mv $f $numf
    done

## Check date integrity

    # WARNING! Check which timezone these pictures were taken!
    
    CHKFILE=IMG_3402.MOV

    for CHKFILE in *MOV; do
        DATE1=$(gstat --format="%y" $CHKFILE);
        DATE2=$(ffmpeg -i $CHKFILE 2>&1 | grep creation_time | head -n 1 | awk '{print $3}');
        NORMDATE1=$(gdate --date="${DATE1}" +%s);
        NORMDATE2=$(gdate --date="${DATE2}" +%s);
        DATEDELTA=$(($NORMDATE1 - $NORMDATE2));
        # https://stackoverflow.com/questions/29223313/absolute-value-of-a-number
        DATEDELTAABS=${DATEDELTA#-};
        #if [[ $DATEDELTAABS -gt 60 ]]; then;
        echo "$CHKFILE - dates differ by: $DATEDELTAABS";
        #fi;
        echo $DATE1 $DATE2
    done;


## Touch movies based on creation date

Works for iPhone movies, not well tested

    for mov in *MOV; 
      do echo $mov;
      NEWDATE=$(ffmpeg -i $mov 2>&1 | grep creation_time | head -n 1 | awk '{print $3}');
      echo $NEWDATE;
      gtouch --date $NEWDATE $mov;
    done

    INFILE=IMG_9595.MOV; INFILEDATE=$(ffmpeg -i $INFILE 2>&1 | grep creation_time | head -n 1 | cut -f 2- -d:); gtouch --date $(echo $INFILEDATE) $INFILE

    for INFILE in $arr;
      do INFILEDATE=$(ffmpeg -i $INFILE 2>&1 | grep creation_time | head -n 1 | cut -f 2- -d:);
      gtouch --date $(echo $INFILEDATE) $INFILE;
    done

arr=(IMG_9474.MOV IMG_9478.MOV IMG_9497.MOV IMG_9570.MOV IMG_9571.MOV IMG_9572.MOV IMG_9573.MOV IMG_9577.MOV)

## Add suffix to filenames

For example to distinguish different photographers

    for file in DSC*JPG
      do mv "$file" "${file%\.*}-reinier.${file##*\.}"
    done


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

# Convert picasa rating to iptc

## Find picasa starred files

for dir in $(find . -type d); do
    test ! -f ${dir}/.picasa.ini && continue
    cat $dir/.picasa.ini | tr -d "\r" | grep "^star=yes\|^\[" | pcregrep -M "\]\nstar" | grep "^\[" | tr -d "[]"
done

## Convert picasa star to iptc rating=5

for dir in $(find . -type d); do
    test ! -f ${dir}/.picasa.ini && continue
    cat $dir/.picasa.ini | tr -d "\r" | grep "^star=yes\|^\[" | pcregrep -M "\]\nstar" |  grep "^\[" | tr -d "[]" | while read starimg; do 
        echo "${dir}/${starimg}"
        exiftool-5.26 -rating=5 -q -q -m "${dir}/${starimg}"
        jhead -ft "${dir}/${starimg}"
    done
done

WARNING - need to apply jhead -ft after exiftooling, or date is disturbed. Re-run 2018 and 2017
