#!/usr/bin/env sh

set -e

url="https://paste.rs/"

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  $SOURCE
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"

if [ -z $1 ]
then
    echo "No arguments. Run pbfs -h for help" >&2;
    exit 1;
fi

echo "  _____  ____  ______ _____ ";
echo " |  __ \|  _ \|  ____/ ____|";
echo " | |__) | |_) | |__ | (___  ";
echo " |  ___/|  _ <|  __| \___ \ ";
echo " | |    | |_) | |    ____) |";
echo " |_|    |____/|_|   |_____/ ";
echo "                            ";
echo "                            ";

if [ $1 = '-h' ]
then
    echo "$ pbfs path/to/file to upload"
    echo "$ pbfs -s masterHash to download"
    echo "$ pbfs -d masterHash to delete"
fi

if [ -s $1 ] && [ -r $1 ]
then

    echo Converting $1...
    FILEHASH="$(echo $1 | base64)"
    TMPFILE="/tmp/$FILEHASH"
    TMPHASHFILE="/tmp/hashes$FILEHASH"
    xxd -p -u $1 | tr -d '\n' > $TMPFILE

    SIZE="$(stat --printf="%s" $TMPFILE)"
    echo $1 is now $SIZE bytes
    echo ""

    CHUNKS="$[ $SIZE / 40000 + 1 ]"

    echo Splitting into $CHUNKS chunks...
    split -n $CHUNKS -e $TMPFILE $FILEHASH
    echo Done
    echo ""

    CHUNKFILES=($(ls $FILEHASH*))
    
    echo Uploading crumbs:
    
    for index in ${!CHUNKFILES[*]}
    do
        echo -ne "Uploading $[ $index + 1 ] / $CHUNKS\r"
        PASTE="$(cat ${CHUNKFILES[$index]} | curl -s --data-binary @- $url)"
        CRUMBS[$index]=${PASTE#"$url"}
    done
    echo -ne "Uploaded $CHUNKS / $CHUNKS \r\n"
    echo ""

    echo Generating master hash file...

    for item in ${CRUMBS[*]}
    do
        echo $item | base64 >> $TMPHASHFILE
    done

    MASTERBIN="$(xxd -p -u $TMPHASHFILE | tr -d '\n' | curl -s --data-binary @- $url)"

    echo ""
    echo This is your master hash file: ${MASTERBIN#"$url"}

    echo ""
    echo Completed!

    rm $FILEHASH*
    rm $TMPHASHFILE
    rm $TMPFILE

fi

if [ $1 = '-s' ] && [ ! -z "$2" ]
then
    echo Retrieving master hash...

    MASTERHASHHEXA="/tmp/masterhashhexa$2"
    curl -s $url$2 > $MASTERHASHHEXA

    MASTERHASH="/tmp/masterhash$2"
    xxd -p -r $MASTERHASHHEXA > $MASTERHASH

    echo Retrieved

    echo ""
    echo Retrieving files...

    TMPFILEHEXA="/tmp/hexa$2"

    while read -r CRUMBHASH
    do
        CRUMB=$(echo $CRUMBHASH | base64 -d)
        CHUNK=$(curl -s $url$CRUMB)
        echo $CHUNK >> $TMPFILEHEXA
        sleep 1

    done <<< "$(cat $MASTERHASH)"

    echo Files Retrieved

    RANDOMNAME="$(date +%s | sha256sum | base64 | head -c 32 ; echo)"

    xxd -p -r $TMPFILEHEXA > $RANDOMNAME

    echo ""

    echo "./$RANDOMNAME created"

    rm $MASTERHASHHEXA
    rm $MASTERHASH
    rm $TMPFILEHEXA

fi

if [ $1 = '-d' ] && [ ! -z "$2" ]
then
    echo Retrieving master hash...

    MASTERHASHHEXA="/tmp/masterhashhexa$2"
    curl -s $url$2 > $MASTERHASHHEXA

    MASTERHASH="/tmp/masterhash$2"
    xxd -p -r $MASTERHASHHEXA > $MASTERHASH

    echo Retrieved

    echo ""

    HASHES=$(wc -l $MASTERHASH)
    HASHES=${HASHES%" $MASTERHASH"}
    CUR=0

    while read -r CRUMBHASH
    do
        CRUMB=$(echo $CRUMBHASH | base64 -d)
        CUR=$(( CUR+1 ))
        echo "Deleting $CUR / $HASHES"
        curl -s -X DELETE $url$CRUMB > /dev/null
        sleep 1

    done <<< "$(cat $MASTERHASH)"

    echo Files Deleted

    curl -s -X DELETE $url$2 > /dev/null

    echo ""

    echo "$2 deleted"

    rm $MASTERHASHHEXA
    rm $MASTERHASH
fi

echo "";
