#!/bin/bash

### unzip the given archive. IPOL demo system will have renamed it input_0
### option -q makes it quiet.
unzip -q input_0
if [ $? != 0 ]; then # input_0 is not a zip file
  echo "Failed to unzip the uploaded file." > demo_failure.txt
  exit 0
fi

### This stops the script as soon as there is an error
### Need to set this after the zip failure test
set -e

### get binaries path
BIN="$1"
shift

### get value for regristration option
REGISTRATION="$1"
shift

### get parameters for EEF and EF (EEF has one supplementary parameter)
PBETA="$1"
shift
PWSAT="$1"
shift
PBSAT="$1"
shift
PDEPT="$1"
shift
PIMPR="$1"
# PARAMEEF="$@"
# shift
# PARAM_EF="$@" # because of additional (last) param "improve"...
PARAMEEF="$PBETA $PWSAT $PBSAT $PDEPT $PIMPR"
PARAM_EF="$PWSAT $PBSAT $PDEPT"

### find images
# https://unix.stackexchange.com/a/321757
# "find prints a list of file paths delimited by newline characters"
FILELIST=$(find . -not -path '*/\.*' -type f -iname '*.jpg'  \
               -o -not -path '*/\.*' -type f -iname '*.jpeg' \
               -o -not -path '*/\.*' -type f -iname '*.png'  \
               -o -not -path '*/\.*' -type f -iname '*.ppm'  \
               -o -not -path '*/\.*' -type f -iname '*.bmp'  \
               -o -not -path '*/\.*' -type f -iname '*.tif'  \
               -o -not -path '*/\.*' -type f -iname '*.tiff' | sort)

IFSSAVE=$IFS    # set IFS to be newline -- because FILELIST may have spaces.
IFS=$'\n'       # This is used in the whole script

FLA=($FILELIST) # convert to array (based on new IFS)
NB=${#FLA[@]}   # counts number of elements in FLA, i.e., the number of inputs

### rename and move images
UNPACKED="unpacked"
mkdir $UNPACKED
FILENUM=0
FLAMOD=() # File List Array Modified (with standard file names)
for FILE in ${FLA[@]}; do
  FILEEXT="${FILE##*.}" # get extension
  FILENEW="${UNPACKED}/img${FILENUM}.${FILEEXT}" # new (standardised) file name
  mv -v "${FILE}" "${FILENEW}" # move file and print to stdout
  FLAMOD[${FILENUM}]=${FILENEW} # add moved file to array

  #Check if the file is a .jpg and convert to .png
  if [[ "$FILEEXT" == "jpg" ]]; then
      PNGFILE="${UNPACKED}/input_${FILENUM}.png" # new .png file name 
      convert "${FILENEW}" "${PNGFILE}" # convert to .png 
      # After successful conversion, move .png file to current folder 
      mv -v "${PNGFILE}" "input_${FILENUM}.png" 
      FLAMOD[${FILENUM}]="input_${FILENUM}.png" # update array with .png file in current folder 
      rm -v "${FILENEW}" # remove original .jpg file after conversion (optional) 
      FLAMOD[${FILENUM}]="input_${FILENUM}.png" # update array with .png file
      echo ${FLAMOD[${FILENUM}]}
  fi
  FILENUM=$((FILENUM + 1)) # increment
done

if [ $NB == 0 ]; then # zip contains no image
  printf "No image found in uploaded archive.\n\n" > demo_failure.txt
  exit 0
fi
if [ $NB == 1 ]; then # fusing a sequence of only one image causes an error
  printf "Can't fuse a sequence with only one image.\n\n" \
    > demo_failure.txt
  exit 0
fi

### give number of images to IPOL demo system
echo "nb_outputs_ef=$NB" > algo_info.txt

### resize large images (avoid "timeout", generally due to the registration)
mogrify -resize "1200x900>" "${FLAMOD[@]}"

if [ ! $REGISTRATION == 0 ]; then

  ### image registration
  echo "image_registration.sh ${FLAMOD[@]}"
  TIME=$(date +%s)
  image_registration.sh "${FLAMOD[@]}"
  TIMEREG=$(($(date +%s) - $TIME))

  ### find registered images and convert to array based on IFS=$'\n'
  FILELISTREG=$(find . -type f -name '*_registered.png' | sort)
  FLAMOD=($FILELISTREG) # overwrite variable

fi

### IFS takes its value back for the following
IFS=$IFSSAVE

### call script with its parameters
echo "octave -W -qf run_ef.m $PARAM_EF ${FLAMOD[@]}"
echo "octave -W -qf runeef.m $PARAMEEF ${FLAMOD[@]}"
echo ""
TIME=$(date +%s)
### with IPOL this is a bit more complicated.
CURP=$(pwd)
### get shortest path to go from $BIN to $CURP
# IMGP=$(python3 -c "import os.path; print os.path.relpath('$CURP', '$BIN')")
### prepend $IMGP to all images (in $FLA)
# FLA=( "${FLA[@]/#/$IMGP/}" )
FLAMOD=( "${FLAMOD[@]/#/$CURP/}" )

if [ -r input_0.png ]; then
  echo "file is readable"
else
  echo "file not readable"
fi

if identify "input_0.png" >/dev/null 2>&1; then
  echo "image is readable by imagemagick"
else
  echo "image is not redable by imagemagick"
fi

INFO=$(identify -format "Format: %m/nDimensions: %w×%h/nSize: %b/n" input_0.png)
echo "$INFO"

CMD1=$(octave -W -qf ${BIN}/run_ef.m $PARAM_EF "${FLAMOD[@]}")
CMD2=$(echo "(cd ${BIN} && octave -W -qf runeef.m $PARAMEEF ""${FLAMOD[@]})")
parallel ::: "$CMD1" "$CMD2"
mv ${BIN}/*.png ${BIN}/algo_info.txt .  # recup the generated files
TIMEFUSION=$(($(date +%s) - $TIME))

### display recap on computation times
echo ""
[ $REGISTRATION == 1 ] && echo "Total time for registration: $TIMEREG seconds."
echo "Total time for fusion: $TIMEFUSION seconds."

### Hack for demo
### Create a transparent image with the same size as the output image.
### This is used to compute the width of the result gallery (with two columns)
# convert -size $(identify output.png | awk -F' ' '{ print $3 }') xc:none transparent.png

