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
# References
# - https://trac.ffmpeg.org/wiki/Encode/AAC#fdk_vbr
# - https://trac.ffmpeg.org/wiki/Encode/H.264#a1.ChooseaCRFvalue

SOURCE_DIR=$1
EXPORT_ROOT=$2
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

# Check if export dir exists
if [[ ! -d ${EXPORT_ROOT} ]]; then echo "export dir \"${EXPORT_ROOT}\" does not exist, aborting"; exit; fi

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

if [[ $(uname) -eq "Darwin" ]]; then
	# If on Mac, we need SetFile/GetFile to fix creation date/time
	if [[ ! -x ${PROG_SETFILE} ]]; then echo "SetFile not found"; HAVE_TOOLS=0; fi
	if [[ ! -x ${PROG_GETFILEINFO} ]]; then echo "GetFileInfo not found"; HAVE_TOOLS=0; fi
else
	# If not on Mac, set these progs to a noop command
	PROG_SETFILE=true
	PROG_GETFILEINFO=true
fi

if [[ ${HAVE_TOOLS} -eq 0 ]]; then echo "Not all tools available, aborting"; exit; fi

EXPORT_DIR=${EXPORT_ROOT}/$(basename ${SOURCE_DIR} | tr "_" " ")
mkdir -p "${EXPORT_DIR}"
# Source_dir should be like 20180903_holiday_italy_venice_verona
albumname=$(basename ${SOURCE_DIR} | cut -f2- -d_))

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
for img in $(${PROG_EXIFTOOL} -m -q -q -if '$rating' -p '$filename' ${SOURCE_DIR}/(#i)(*{png,mov,mp4,jpg})*(N)); do
	# Split processing between images and video
	ISIMAGE=$(${PROG_FILE} -I ${SOURCE_DIR}/${img} | grep image)
	ISVIDEO=$(${PROG_FILE} -I ${SOURCE_DIR}/${img} | grep video)
	echo "${img} - exporting $ISIMAGE - $ISVIDEO"
	if [[ ${DRY} -eq 0 ]]; then
		# Might use this later for renaming
		filedate=$(${PROG_DATE} -d "$(${PROG_GETFILEINFO} -d ${SOURCE_DIR}/${img})" +%Y%m%d%H%M%S)
		filename=$(echo ${filedate}_${albumname}_${img})
		if [[ -n $ISIMAGE ]]; then
			${PROG_CONVERT} -geometry 1920x1920 -quality 70 ${SOURCE_DIR}/${img} "${EXPORT_DIR}/${img}"
			${PROG_TOUCH} -r "${SOURCE_DIR}/$img" "${EXPORT_DIR}/${img}"
			${PROG_SETFILE} -d "$(${PROG_GETFILEINFO} -d ${SOURCE_DIR}/${img})" "${EXPORT_DIR}/${img}"
			#${PROG_SETFILE} -m "$(${PROG_GETFILEINFO} ${SOURCE_DIR}/${img} | grep modified | ${PROG_CUT} -c11-)" "${EXPORT_DIR}/${img}"
		elif [[ -n $ISVIDEO ]]; then
			# For future features
			#ISIPHONE=$(echo ${SOURCE_DIR}/${img} | grep "IMG_.*MOV")
			#ISEOS=$(echo ${SOURCE_DIR}/${img} | grep "MVI_.*MOV")
			#ISGOPRO=$(echo ${SOURCE_DIR}/${img} | grep "GOPR.*MP4")
			#echo cp ${SOURCE_DIR}/$img ${EXPORT_DIR}/${img}
			nice -n 15 ffmpeg -i ${SOURCE_DIR}/$img -profile:v high -level 4.0 -pix_fmt yuv420p -c:v libx264 -preset slow -metadata date="$(${PROG_STAT} --format="%y" $img | ${PROG_CUT} -f 1-2 -d' ')" -crf 28 -vf scale=1280:-1 -c:a libfdk_aac -vbr 3 -threads 0 -y "${EXPORT_DIR}/${img}-x264_aac.mp4"
			${PROG_TOUCH} -r "${SOURCE_DIR}/$img" "${EXPORT_DIR}/${img}-x264_aac.mp4"
			${PROG_SETFILE} -d "$(${PROG_GETFILEINFO} -d ${SOURCE_DIR}/${img})" "${EXPORT_DIR}/${img}-x264_aac.mp4"
			#${PROG_SETFILE} -m "$(${PROG_GETFILEINFO} ${SOURCE_DIR}/${img} | grep modified | ${PROG_CUT} -c11-)" "${EXPORT_DIR}/${img}-x264_aac.mp4"
		else
			echo "WARNING - unrecognized filetype"
		fi
	fi
done

#shopt -u nocaseglob # Unsets nocaseglob
#shopt -u nullglob # Unsets nullglob