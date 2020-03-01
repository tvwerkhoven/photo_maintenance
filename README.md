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

    exiftool '-time:all<$DateTimeORiginal' -wm w -P *aac.mp4
    exiftool '-time:all<$ContentCreateDate' -wm w -P *aac.mp4
    exiftool '-time:all<$FileModifyDate' -wm w -P *aac.mp4

    touch -t 201702261838.52 TRIM_20170226_183852-basb.mp4-x264_aac.mp4
    exiftool '-time:all<$FileModifyDate' -wm w -P *basb.mp4-x264_aac.mp4

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

    find . -type f -name "MVI*" | while read -r _file; do
      _filedate=$(gstat --format=%Y "${_file}")
      _datestr=$(gdate --iso=s --date="@${_filedate}" | tr 'T' ' ')
      ffmpeg -y -nostdin -i "${_file}" -metadata ICRD="${_datestr}" -c copy test.avi
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
