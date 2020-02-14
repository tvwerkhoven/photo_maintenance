#!/usr/bin/env zsh
# 
# # Usage
#   ./publish_pics.sh <source_dir> <export_dir>
#
# For all images (png, mov, mp4, jpg) with the 'rating' parameter set in 
# <source_dir>, convert to lower resolution and store in <export_dir>.
# The script will make a new directory in <export_dir> named <source_dir>,
# where _ are replaced with space. This enables iPhones to look for 
# 
# For images: downscale max resolution to 1920 pixels, quality 70, jpeg
# For videos: convert to x264 with quality crf 23 and max resolution 1280 and 
#             aac audio with vbr 3 rate (48-56 kbps/channel)
#
# # Examples
#   ./publish_pics.sh ~/Pictures/200600519_wedding_party_new_york ./Pictures/pics_lossy
# will create a folder "200600519 wedding party new york" in ./Pictures/pics_lossy
# 
# # Pre-requisites
# 
# 1. exiftool
# 2. zsh
# 3. convert
# 4. file
#
# # Fix dates of movies
#
# ffmpeg -i IMG_9591_trim1_copy.mov -metadata date="$(stat --printf='%y' IMG_9591_trim1_copy.mov | cut -d ' ' -f1)" -codec copy IMG_9591_trim1_copy2.mov
# 
# References
# - https://trac.ffmpeg.org/wiki/Encode/AAC#fdk_vbr
# - https://trac.ffmpeg.org/wiki/Encode/H.264#a1.ChooseaCRFvalue

if [[ $1 = "-h" ]] || [[ $1 = "--help" ]] || [[ $# -lt 1 ]]; then
	echo "Usage: $(basename $0) <export_dir> [source_dir=.] "
	exit
fi

EXPORT_ROOT=$1
if [[ $# -gt 1 ]]; then
	SOURCE_DIR=$(cd $2; pwd)
else
	SOURCE_DIR=$(pwd)
fi
echo ${SOURCE_DIR}

DRY=0

PROG_EXIFTOOL=/opt/local/bin/exiftool
PROG_FILE=/usr/bin/file
PROG_CONVERT=/opt/local/bin/convert
PROG_TOUCH=/usr/bin/touch
PROG_SETFILE=/usr/bin/SetFile
PROG_GETFILEINFO=/usr/bin/GetFileInfo
PROG_STAT=/opt/local/bin/gstat
PROG_FFMPEG=/opt/local/bin/ffmpeg
PROG_NICE=/usr/bin/nice
PROG_CUT=/usr/bin/cut
PROG_DATE=/opt/local/bin/gdate
PROG_MP4EXTRACT=/usr/local/bin/mp4extract
PROG_MP4EDIT=/usr/local/bin/mp4edit

# Check if source an export dir exists
if [[ ! -d ${EXPORT_ROOT} ]]; then echo "export dir \"${EXPORT_ROOT}\" does not exist, aborting"; exit; fi
if [[ ! -d ${SOURCE_DIR} ]]; then echo "source dir \"${SOURCE_DIR}\" does not exist, aborting"; exit; fi


# Check if tools exist
HAVE_TOOLS=1
if [[ ! -x ${PROG_EXIFTOOL} ]]; then echo "exiftool not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_FILE} ]]; then echo "file not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_CONVERT} ]]; then echo "convert not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_TOUCH} ]]; then echo "touch not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_STAT} ]]; then echo "(g)stat not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_FFMPEG} ]]; then echo "ffmpeg not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_NICE} ]]; then echo "nice not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_CUT} ]]; then echo "cut not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_DATE} ]]; then echo "(g)date not found"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_MP4EXTRACT} ]]; then echo "mp4extract not found - get from https://www.bento4.com/"; HAVE_TOOLS=0; fi
if [[ ! -x ${PROG_MP4EDIT} ]]; then echo "mp4edit not found - get from https://www.bento4.com/"; HAVE_TOOLS=0; fi

if [[ $(uname) -eq "Darwin" ]]; then
	# If on Mac, we need SetFile/GetFile to fix creation date/time
	if [[ ! -x ${PROG_SETFILE} ]]; then echo "SetFile not found"; HAVE_TOOLS=0; fi
	if [[ ! -x ${PROG_GETFILEINFO} ]]; then echo "GetFileInfo not found"; HAVE_TOOLS=0; fi
else
	# If not on Mac, set these progs to a noop command (untested)
	PROG_SETFILE=true
	PROG_GETFILEINFO=true
fi

if [[ ${HAVE_TOOLS} -eq 0 ]]; then echo "Not all tools available, aborting"; exit; fi

# Source_dir should be like 20180903_holiday_italy_venice_verona
EXPORT_DIR=${EXPORT_ROOT}/$(basename ${SOURCE_DIR} | tr "_" " ")
mkdir -p "${EXPORT_DIR}"
#albumname=$(basename ${SOURCE_DIR} | cut -f2- -d_)

# for globbing https://stackoverflow.com/a/41139446
# TODO does not work in zsh?
#shopt -s nullglob # Sets nullglob
#shopt -s nocaseglob # Sets nocaseglob

setopt extendedglob # for zsh - https://stackoverflow.com/a/157425
# -m ignores errors, -q -q ignores final summary, -if filters, -p prints
# https://photo.stackexchange.com/questions/56677
# (#i)(*{png,mov,mp4,jpg})*(N) for zsh (#i) - insensitive, (N) to ignore missing hits
# https://unix.stackexchange.com/a/298625
# *.{JPG,PNG,MOV,MP4}) for bash
# https://stackoverflow.com/a/41139446

# First set file date to creation date from metadata, movies and images 
# separately because different tags. Use -wm w to not create new tags
# See: https://photo.stackexchange.com/questions/83657/any-program-to-change-date-created-of-videos-to-actual-exif-data
# Not sure which works reliably for videos
# See: https://exiftool.org/forum/index.php?topic=6318.msg33921#msg33921
${PROG_EXIFTOOL} "-CreationDate>FileModifyDate" -wm w ${SOURCE_DIR}/(#i)(*{mov,mp4})*(N)
${PROG_EXIFTOOL} "-CreateDate>FileModifyDate" -wm w ${SOURCE_DIR}/(#i)(*{mov,mp4})*(N)
${PROG_EXIFTOOL} "-DateTimeOriginal>FileModifyDate" -wm w ${SOURCE_DIR}/(#i)(*{png,jpg})*(N)

# If no exif timestamps, set here from filedate
${PROG_EXIFTOOL} -if '(not $datetimeoriginal)' "-FileModifyDate>DateTimeOriginal" ${SOURCE_DIR}/(#i)(*{png,jpg})*(N)

for img in $(${PROG_EXIFTOOL} -m -q -q -if '$rating' -p '$filename' ${SOURCE_DIR}/(#i)(*{png,mov,mp4,jpg})*(N)); do
	# Use mime-type to distinguish between video and images
	ISIMAGE=$(${PROG_FILE} --mime-type ${SOURCE_DIR}/${img} | grep image | cut -d':' -f2)
	ISVIDEO=$(${PROG_FILE} --mime-type ${SOURCE_DIR}/${img} | grep video | cut -d':' -f2)
	if [[ ${DRY} -eq 0 ]]; then
		# Might use this later for renaming
		# filedate=$(${PROG_DATE} -d "$(${PROG_GETFILEINFO} -d ${SOURCE_DIR}/${img})" +%Y%m%d%H%M%S)
		# filename=$(echo ${filedate}_${albumname}_${img})
		if [[ -n $ISIMAGE ]]; then
			echo "${img} - exporting ${ISIMAGE}${ISVIDEO}"
			# USe \> to only resize larger images than desired size 
			# http://www.imagemagick.org/Usage/resize/#shrink
			# https://stackoverflow.com/a/6387086
			${PROG_CONVERT} -geometry 1920x1920\> -quality 70 ${SOURCE_DIR}/${img} "${EXPORT_DIR}/${img}"
			${PROG_TOUCH} -r "${SOURCE_DIR}/$img" "${EXPORT_DIR}/${img}"
			${PROG_SETFILE} -d "$(${PROG_GETFILEINFO} -d ${SOURCE_DIR}/${img})" "${EXPORT_DIR}/${img}"
			#${PROG_SETFILE} -m "$(${PROG_GETFILEINFO} ${SOURCE_DIR}/${img} | grep modified | ${PROG_CUT} -c11-)" "${EXPORT_DIR}/${img}"
		elif [[ -n $ISVIDEO ]]; then
			echo "${img} - exporting ${ISIMAGE}${ISVIDEO}"
			# From ffmpeg info, look for three-digit fps (xxx.xx fps), which 
			# means it's slomo. We could make this more exact by checking for 
			# fps > 30, but that's too complicated
			ISSLOMO=$(ffmpeg -i ${SOURCE_DIR}/${img} 2>&1 | grep "[0-9]\{3,\}.[0-9]\{2,\} fps,")
			if  [[ -n $ISSLOMO ]]; then
				echo -n "Cannot process slo-mo video. Please convert in QuickTime (Player) manually, OK?"
				read answer
			else
				# For future features
				ISIPHONE=$(echo ${SOURCE_DIR}/${img} | grep "IMG_.*MOV")
				#ISEOS=$(echo ${SOURCE_DIR}/${img} | grep "MVI_.*MOV")
				#ISGOPRO=$(echo ${SOURCE_DIR}/${img} | grep "GOPR.*MP4")
				#echo cp ${SOURCE_DIR}/$img ${EXPORT_DIR}/${img}

				# Convert to nice file format. Get the video metadata date 
				# from the modification time (stat) of the source file
				# Reduce output clutter: -hide_banner -nostats -loglevel error 
				# Copy all metadata: -movflags use_metadata_tags -- https://superuser.com/questions/1208273/add-new-and-non-defined-metadata-to-a-mp4-file -- https://video.stackexchange.com/questions/23741/how-to-prevent-ffmpeg-from-dropping-metadata
				# SUPERSEDED: Set original data in metadata: -metadata date="$(${PROG_STAT} --format="%y" ${SOURCE_DIR}/${img} | ${PROG_CUT} -f 1-2 -d' ')"
				# nice -n 15 ${PROG_FFMPEG} -hide_banner -nostats -loglevel error -i ${SOURCE_DIR}/$img -profile:v high -level 4.0 -pix_fmt yuv420p -c:v libx264 -preset slow  -metadata date="$(${PROG_STAT} --format="%y" ${SOURCE_DIR}/${img} | ${PROG_CUT} -f 1-2 -d' ')" -crf 28 -vf scale=1280:-1 -c:a libfdk_aac -vbr 3 -threads 0 -y "${EXPORT_DIR}/${img}-x264_aac.mp4"
				# nice -n 15 ${PROG_FFMPEG} -hide_banner -nostats -loglevel error -i ${SOURCE_DIR}/$img -profile:v high -level 4.0 -pix_fmt yuv420p -c:v libx264 -preset slow -movflags use_metadata_tags -crf 28 -vf scale=1280:-1 -c:a libfdk_aac -vbr 3 -threads 0 -y "${EXPORT_DIR}/${img}-x264_aac.mp4"
				nice -n 15 ${PROG_FFMPEG} -hide_banner -nostats -loglevel error -i ${SOURCE_DIR}/$img -profile:v high -level 4.0 -pix_fmt yuv420p -c:v libx264 -preset slow -movflags use_metadata_tags -crf 28 -vf scale=1280:-1 -c:a libfdk_aac -vbr 3 -threads 0 -y "${EXPORT_DIR}/${img}-x264_aac.mp4"

				if  [[ -n $ISIPHONE ]]; then
					# Fix GPS metadata with https://www.bento4.com/
					${PROG_MP4EXTRACT} moov/meta "${SOURCE_DIR}/$img" "${EXPORT_DIR}/metadata-gps"
					${PROG_MP4EDIT} --insert moov:"${EXPORT_DIR}/metadata-gps" "${EXPORT_DIR}/${img}-x264_aac.mp4" "${EXPORT_DIR}/${img}-x264_aac-gps.mp4"
					mv "${EXPORT_DIR}/${img}-x264_aac-gps.mp4" "${EXPORT_DIR}/${img}-x264_aac.mp4"
				fi
				
				# Set modification and creation(?) time the same as source file 
				# using touch and Mac's GetFileInfo / SetFileInfo
				${PROG_TOUCH} -r "${SOURCE_DIR}/$img" "${EXPORT_DIR}/${img}-x264_aac.mp4"
				${PROG_SETFILE} -d "$(${PROG_GETFILEINFO} -d ${SOURCE_DIR}/${img})" "${EXPORT_DIR}/${img}-x264_aac.mp4"
				#${PROG_SETFILE} -m "$(${PROG_GETFILEINFO} ${SOURCE_DIR}/${img} | grep modified | ${PROG_CUT} -c11-)" "${EXPORT_DIR}/${img}-x264_aac.mp4"
			fi
		else
			echo "WARNING - unrecognized filetype"
		fi
	fi
done

## ONLY WORKS FOR IMAGES
# After converting images, set keywords on all newly converted files:
albumdir_tag=$(basename ${EXPORT_DIR} | tr '[:upper:]' '[:lower:]')
exiftags=()
exiftags+="-IPTC:Keywords+=${albumdir_tag}"
pngtags=()
pngtags+="-XMP:Subject+=${albumdir_tag}"
# Skip date (=first space-separated word) in separate keywords, then add the rest if length is more than 2 letters
albumdir_tag_nodate=${albumdir_tag#* }
# use ${=albumdir_tag_nodate} for zsh, see https://scriptingosx.com/2019/08/moving-to-zsh-part-8-scripting-zsh/
for thiskeyword in ${=albumdir_tag_nodate}; do 
    if [ $(echo $thiskeyword | wc -c) -gt 3 ]; then
        exiftags+="-IPTC:Keywords+=${thiskeyword}"
        pngtags+="-XMP:Subject+=${thiskeyword}"
    fi
done
# Add png tags and exif tags separately
# See https://stackoverflow.com/questions/19154596/exiftool-to-create-osx-visible-xmp-metadata-in-png-images

${PROG_EXIFTOOL} -overwrite_original ${pngtags} "-DateTimeOriginal>FileModifyDate" ${EXPORT_DIR}/(#i)(*png)*(N)
${PROG_EXIFTOOL} -overwrite_original ${exiftags} "-DateTimeOriginal>FileModifyDate" ${EXPORT_DIR}/(#i)(*jpg)*(N)

#${PROG_EXIFTOOL} "-DateTimeOriginal>FileModifyDate" ${EXPORT_DIR}/(#i)(*{png,jpg})*(N)

# Unset for bash, see above
#shopt -u nocaseglob # Unsets nocaseglob
#shopt -u nullglob # Unsets nullglob