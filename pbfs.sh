#!/usr/bin/env bash

set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  $SOURCE
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"

if [ -s $DIR/.env ] && [ -r $DIR/.env ]
then
    . $DIR/.env
else
    echo "No .env file or not readable" >&2;
    exit 1;
fi

if [ -z $* ]
then
    echo "No arguments" >&2;
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

    CHUNKS="$[ $SIZE / 40000 ]"

    echo Splitting into $CHUNKS chunks...
    split -n $CHUNKS -e $TMPFILE $FILEHASH
    echo Done
    echo ""

    CHUNKFILES=($(ls $FILEHASH*))
    
    echo Uploading crumbs:
    
    for index in ${!CHUNKFILES[*]}
    do
        echo -ne "Uploading $[ $index + 1 ] / $CHUNKS\r"
        url="https://pastebin.com/"
        PASTE="$(curl -s -X POST -d "api_dev_key=$PASTEBIN_KEY&api_option=paste&api_paste_code=$(cat ${CHUNKFILES[$index]})" https://pastebin.com/api/api_post.php)"
        CRUMBS[$index]=${PASTE#"$prefix"}
    done
    echo -ne "Uploaded $CHUNKS / $CHUNKS \r\n"
    echo ""

    echo Generating master hash file...

    for item in ${CRUMBS[*]}
    do
        echo $item | base64 >> $TMPHASHFILE
    done

    MASTERBIN="$(curl -s -X POST -d "api_dev_key=$PASTEBIN_KEY&api_option=paste&api_paste_code=$(xxd -p -u $TMPHASHFILE | tr -d '\n')" https://pastebin.com/api/api_post.php)"

    echo ""
    echo This is your maste hash file: $MASTERBIN

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
    curl -s https://pastebin.com/raw/$2 > $MASTERHASHHEXA

    MASTERHASH="/tmp/masterhash$2"
    xxd -p -r $MASTERHASHHEXA > $MASTERHASH

    echo Retrieved

    echo ""
    echo Retrieving files...

    TMPFILEHEXA="/tmp/hexa$2"

    while read -r CRUMBHASH
    do
        CRUMB=$(echo $CRUMBHASH | base64 -d)
        CHUNK=$(curl -s -A "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.111 Safari/537.36" https://pastebin.com/raw/$CRUMB)
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

echo "";
