# About

This is a collection of scripts to maintain and publish photo archives.

# Scripts

1. publish_pics.sh: compress pictures & videos ready for publishing
2. picasa2iptc.sh: convert Picasa rating to IPTC rating
2. par_create.sh / par_check.sh: protect against bitrot via par2

## publish_pics.sh

To publish pictures in lower resolution to the web or phone. I use this to
store more pictures on my iPhone, for example.

Syntax:

    ./publish_pics.sh --help --debug --no-vids --no-pics --dry-run -s | --sourcedir <sourcedir> <export_root>

Example:

    ./publish_pics.sh --debug -s ~/Pictures/200600519_wedding_party_new_york ./Pictures/pics_lossy

1. Check if all required tools are available (edit paths in script pre-amble if needed)
2. Prepare input: set file modification date to datetime created
3. Make output directory in `export_root` based on `sourcedir` with `_` replaced by space so iOS >12 can look 
for these folders as keywords when synchronizing using iTunes
4. Convert pictures: for all png & jpg, convert down to 1920 pixels max size and quality 70, preserving metadata
5. Tag pictures: Add XMP/IPTC keywords based on `sourcedir` to all pictures: split directory name by `_` and add each word as keyword if it's 3 or more characters
6. Convert videos: to x264 with quality crf 23 and max resolution 1280 and aac audio with vbr 3 rate (48-56 kbps/channel). If this is an iPhone video, transplant the moov/meta metadata atom to preserve geotags.
7. Geotag all files: add geotag to files not already having one by interpolating between existing geotags. Additionally add moov/meta geotag on non-iPhone files so iOS/macOS can recognize these geotags

## picasa2iptc.sh

Convert Picasa rating to IPTC rating. Fairly straightforward.

## par_create.sh / par_check.sh

To prevent bitrot when the filesystem does not take care of this (e.g. on 
macOS), one can use `par2` to manually create and check integrity.

# Todo

- Set keywords for videos: no idea how
- Set timestamps in PNG files properly: need to implement
- Figoure out HDR creation on Mac
- Document and detail out current workflow

# On geotagging videos for iOS

iOS/macOS stores geotags in the moov/meta atom of mp4 metadata. This is not
where ffmpeg or exiftool store video geotags normally. To mitigate this, I
use the following approach:

1. Geotag videos using exiftool (using XMP metadata). Alternatively do this via your favorite GUI. Using exiftool allows interpolating a gpx track so I don't have to do it manually and can base my video geotags on existing other geotags.
2. Harvest geotag metadata stored in the moov/meta atom from an existing iOS video using bento4 SDK mp4extract
3. Update the moov/meta atom manually using the XMP geotag in the video file
4. Transplant the updated moov/meta atom in the new video using mp4edit

This is somewhat hacky but it seems to work reliably. The moov/meta atom
stores more data than just geotag, such as iPhone model and iOS version, so 
each transplanted video will have this wrong metadata.

## Background info

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

# On video keywords for Mac

Not working:
- Add keywords via Photos.app, then AirDrop
- Add keywords via Photos.app, then export as original
- Add keywords via Photos.app, then export
- Add keywords via Photos.app, then sync with iPhone
- Add keywords via Bridge, then Rollit
- Add keywords via Exiftool, with IPTC:Keywords, then Rollit
- Add keywords via Exiftool, with quicktime:keywords, then Rollit

# Video sync via 'Sync photos'

## Problem

Some videos, including “IMG_3904.MOV.v5.main_4.0_faststart_aac.mp4”, were not copied to the iPhone “iPhone SE Neptune” Some videos because they cannot be played on this iPhone.

Problem seemed to be -movflags use_metadata_tags

## Testing

_file=IMG_3904.MOV


### Does not work

    nice -n 15 ffmpeg -hide_banner -nostdin -nostats -loglevel error -i "${_file}" -profile:v high -level 4.0 -pix_fmt yuv420p -c:v h264 -preset slower -movflags use_metadata_tags -crf 26 -vf "scale='round(iw * min(0.5,sqrt(1280*720/ih/iw)/2))*2:-2" -c:a libfdk_aac -vbr 3 -threads 0 -y "${_file}.original.mp4"

    ffmpeg -i "${_file}" -c:v libx264 -profile:v high -vf "format=yuv420p,scale=-2:720:flags=lanczos" -c:a aac -preset faster -movflags +faststart -metadata com.apple.quicktime.keywords="tobiah, 4bf44caeff42"  "${_file}.v11.simple_720p_keywords2.mp4"

    nice -n 15 ffmpeg -hide_banner -nostdin -nostats -loglevel error -i "${_file}" -profile:v high -level 4.0 -pix_fmt yuv420p -c:v h264 -preset faster -movflags use_metadata_tags -crf 26 -vf "scale='round(iw * min(0.5,sqrt(1280*720/ih/iw)/2))*2:-2" -c:a libfdk_aac -vbr 3 -threads 0 -y "${_file}.v1.original.mp4"

    nice -n 15 ffmpeg -hide_banner -nostdin -nostats -loglevel error -i "${_file}" -profile:v baseline -level 3.0 -pix_fmt yuv420p -c:v h264 -preset faster -movflags use_metadata_tags -crf 26 -vf "scale='round(iw * min(0.5,sqrt(1280*720/ih/iw)/2))*2:-2" -c:a libfdk_aac -vbr 3 -threads 0 -y "${_file}.v2.baseline_3.0.mp4"

    nice -n 15 ffmpeg -hide_banner -nostdin -nostats -loglevel error -i "${_file}" -profile:v baseline -level 3.0 -pix_fmt yuv420p -c:v h264 -preset faster -movflags use_metadata_tags -movflags +faststart -crf 26 -vf "scale='round(iw * min(0.5,sqrt(1280*720/ih/iw)/2))*2:-2" -c:a libfdk_aac -vbr 3 -threads 0 -y "${_file}.v3.baseline_3.0_faststart.mp4"

    nice -n 15 ffmpeg -hide_banner -nostdin -nostats -loglevel error -i "${_file}" -profile:v baseline -level 3.0 -pix_fmt yuv420p -c:v h264 -preset faster -movflags use_metadata_tags -movflags +faststart -crf 26 -vf "scale='round(iw * min(0.5,sqrt(1280*720/ih/iw)/2))*2:-2" -c:a aac -vbr 3 -threads 0 -y "${_file}.v4.baseline_3.0_faststart_aac.mp4"

    nice -n 15 ffmpeg -hide_banner -nostdin -nostats -loglevel error -i "${_file}" -profile:v main -level 4.0 -pix_fmt yuv420p -c:v h264 -preset faster -movflags use_metadata_tags -movflags +faststart -crf 26 -vf "scale='round(iw * min(0.5,sqrt(1280*720/ih/iw)/2))*2:-2" -c:a aac -vbr 3 -threads 0 -y "${_file}.v5.main_4.0_faststart_aac.mp4"


    ffmpeg -i "${_file}" -c:v libx264 -profile:v high -vf "format=yuv420p" -vf "scale=-2:720:flags=lanczos" -c:a aac -movflags +faststart -movflags use_metadata_tags "${_file}.v10.simple_720p_metadatatags.mp4"

### Does work

    ffmpeg -i "${_file}" -c:v libx264 -profile:v main -vf "format=yuv420p" -c:a aac -movflags +faststart "${_file}.v6.simple.mp4"

    ffmpeg -i "${_file}" -c:v libx264 -profile:v main -vf "format=yuv420p" -vf "scale=-2:720:flags=lanczos" -c:a aac -movflags +faststart "${_file}.v7.simple_720p.mp4"

    exiftool -TagsFromFile IMG_3904.MOV -All:All  IMG_3904.MOV.v8.simple_720p_keywords.mp4

Not sure if keywords are working (no, keywords don't work):

    ffmpeg -i "${_file}" -c:v libx264 -profile:v main -vf "format=yuv420p" -vf "scale=-2:720:flags=lanczos" -c:a aac -preset faster -movflags +faststart -metadata com.apple.quicktime.keywords="tobiah, 4bf44caeff42"  "${_file}.v9.simple_720p_keywords2.mp4"

    ffmpeg -i "${_file}" -c:v libx264 -profile:v high -vf "format=yuv420p,scale=-2:720:flags=lanczos" -c:a aac -preset faster -movflags +faststart -metadata com.apple.quicktime.keywords="tobiah, 4bf44caeff42"  "${_file}.v11.simple_720p_keywords2.mp4"


    ffmpeg -i "${_file}" -c:v libx264 -profile:v high -vf "format=yuv420p,scale='round(iw * min(0.5,sqrt(1920*1080/ih/iw)/2))*2':-2:flags=lanczos" -c:a libfdk_aac -vbr 3 -preset faster -movflags +faststart "${_file}.v12.simple_720p.mp4"

# One-liners

## Preparing for marktplaats

- anonimize exif
- reduce resolution/size to 2MP


    find . -type f -iname "*jpg" | while read file; do
        convert -resize 2073600@ -auto-orient -strip "${file}" "${file%.*}-marktplaats.${file##*\.}"
    done


## Reducing file size for archiving

For non-rated files, reduce to <=9M @ 75 or 80 quality with acceptable quality loss

    for img in $(exiftool -m -q -q -if 'not $rating' -p '$filename' *{JPG,jpg}); do echo $img; convert -resize 3000x3000 -quality 80 $img temp.jpg && mv temp.jpg $img; done


## Find non-keyworded images

Find images where somehow we didn't set image keywords (-subject)

exiftool -keywords -subject /Users/tim/Nextcloud/pics_lossy12/20110703--18\ vacation\ georgia/IMG_0111_eos.JPG
exiftool -keywords -subject /Users/tim/Nextcloud/pics_lossy12/20211127\ verjaardag\ cok\ jannie\ wormshoef/IMG_7506.JPG
exiftool -keywords -subject /Users/tim/Nextcloud/pics_lossy12/20220114\ alexandra\ hofje\ leuning\ stoeltje\ muts\ raam/IMG_1662.heic

for dir in 202203*; do
    TAGGED=$(exiftool -q -if 'not $keywords and not $subject' -ext PNG -ext JPG -ext JPEG -ext HEIC "${dir}"/* -p '$directory/$filename')
    echo "$(ls $dir | wc -l)\t$(echo $TAGGED | wc -l)\t$dir"
done

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


## Add suffix to filenames

For example to distinguish different photographers

    for file in DSC*JPG
      do mv "$file" "${file%\.*}-reinier.${file##*\.}"
    done

## Check if we have originals for converted videos


    while read _file; do
        if [[ ! -f ${_file%*-x264_aac.mp4} ]]; then
            dirname "${_file%*-x264_aac.mp4}"
        fi
    done < <(find . -name "*-x264_aac.mp4") | uniq

## Set all metadata time tags

    exiftool '-time:all<$DateTimeOriginal' -wm w -P *aac.mp4
    exiftool '-time:all<$ContentCreateDate' -wm w -P *.mp4
    exiftool '-time:all<$FileModifyDate' -wm w -P *aac.mp4


    touch -t 201702261838.52 TRIM_20170226_183852-basb.mp4-x264_aac.mp4
    exiftool '-time:all<$FileModifyDate' -wm w -P *basb.mp4-x264_aac.mp4

    exiftool -TagsFromFile $FIRSTFILE '-time:all<$DateTimeOriginal' 20200322_timelapse_plants_amaryllis-06-x264_aac.mp4

Forcibly create DateTimeOriginal

    exiftool '-DateTimeOriginal<$FileModifyDate' -wm wc -P *jpg

## Match time from adjacent files

Manually

    exiftool -q -p '$filename,$DateTimeOriginal' IMG_086*
    exiftool -tagsfromfile IMG_0863.JPG '-time:all<$DateTimeOriginal' -wm w -P IMG_0862.MOV-x264_aac.mp4

In a script (MVI_XXXX.AVI to IMG_XXXX.JPG)

    find . -type f -name "MVI*" | while read -r _file; do
      _ffile=$(basename $_file)
      _id=${_ffile:4:4}
      _lastrefffile=
      find . -type f -name "IMG*" | sort | while read -r _reffile; do
        _refffile=$(basename "${_reffile}")
        _rid=${_refffile:4:4}
        if [[ "${_rid}" -gt "${_id}" ]]; then
          echo "${_ffile}" "${_lastrefffile}" "${_refffile}"
          touch -r "${_lastrefffile}" "${_ffile}"
          break
        fi
        _lastrefffile=${_refffile}
      done
    done


## Set avi timestamps

    ffmpeg -i MVI_0687.AVI.xvid.avi -metadata ICRD="2006-08-17 16:19:05+02:00" -c copy test.avi

Loop over files, set file modification time to CreateDate

    find . -type f -name "*AVI" | while read -r _file; do
      _filedate=$(gstat --format=%Y "${_file}")
      _datestr=$(gdate --iso=s --date="@${_filedate}" | tr 'T' ' ')
      ffmpeg -y -nostdin -i "${_file}" -movflags use_metadata_tags -metadata ICRD="${_datestr}" -c copy test.avi
      touch -r "${_file}" test.avi
      mv test.avi "${_file}"
    done

Source: https://superuser.com/questions/1141299/change-avi-metadata-creation-date-with-ffmpeg-issue

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

# Solve one-time stuff

## Fix timestamps on wrongly timestamped videos

At least 2022 and 2021 videos are affected

find . -type f -iname "*mp4" | grep "^./2022" | while read vidfile; do
    echo $vidfile;
    exiftool -time:all $vidfile
done

SRCFILE=/Users/tim/Pictures/2022/dir/IMG_3385.MOV
DSTFILE=IMG_3385.MOV-x264_aac.mp4

touch -r "${SRCFILE}" "${DSTFILE}"
exiftool -tagsfromfile "${SRCFILE}" '-time:all' -overwrite_original -wm w -P "${DSTFILE}"

## Find matching exported directory

    find . > ~/Pictures/index-losssy-20220410.txt

    find . -type d -not -path "." | sort -n | while read DIR; do SDIR=$(echo $DIR | cut -c 3- | tr "_" " "); grep -q "$SDIR" ~/Pictures/index-losssy-20220506.txt > /dev/null || echo NOT FOUND $SDIR -- $(find "$DIR" -type f | \grep -o '[^\.]*$' | sort | uniq -c | xargs); done

Tips from
* https://stackoverflow.com/questions/4210042/how-to-exclude-a-directory-in-find-command
* https://unix.stackexchange.com/questions/516161/printing-a-string-when-grep-does-not-get-a-match


## One-time script

find . -type d -iname "19*" | while read dir; do
    touch -t "$dir[3,10]1200" $dir/*
    exiftool '-time:all<$FileModifyDate' -wm w -P $dir/*jpg
done


find . -type d -iname "19*" | while read dir; do
    echo $dir
    cd $dir;
    ~/Pictures/maintenance/publish_pics.sh --debug ~/stack/pics_lossy12
    cd ..
done

## No DateTimeOriginal

Check which photos have no DateTimeOriginal. Check dates of pics in folders 20051112 GAMMA is wrong
    
    exiftool -quiet -ignoreMinorErrors -if 'not $DateTimeOriginal' -printFormat '$filepath' -r *

/Users/tim/Pictures/2003/20030803_tim_parachute_Texel
/Users/tim/Pictures/2004/20040000_pictures_done
/Users/tim/Pictures/2004/20040000_portfolio
/Users/tim/Pictures/2004/20040708_joel_jasper_cor_bloomingdale
/Users/tim/Pictures/2004/20040909_gamma_bowlen
/Users/tim/Pictures/2005/20050315_antwerpen
/Users/tim/Pictures/2005/20050701_tom_ton_den-haag
/Users/tim/Pictures/2005/20050721--0806_Canada_Calgary_Joel/IMG_5915.JPG
/Users/tim/Pictures/2005/20051112_GAMMA

## Scratch


for i in *gif; do
    timestamp=$(echo $i | cut -c7-22 | tr -d "-" | tr -d "_");
    echo $timestamp;
    touch -t $timestamp $i
done

exiftool '-time:all<$FileModifyDate' -overwrite_original -wm w -P *gif