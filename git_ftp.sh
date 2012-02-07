#!/bin/bash

#~ @TODO create recursive dir if not exist


#define some conf vars

readMissingFromSTDIN=0

while getopts ":hH:iu:p:P:" opt; do
  case $opt in
    h)
      echo "Help !!"
      exit 1
      ;;
    H)
      ftpHost=$OPTARG
      ;;
    i)
      #missing params will be read from STDIN
      readMissingFromSTDIN=1
      ;;
    u)
      ftpUser=$OPTARG
      ;;
    p)
      ftpPassword=$OPTARG
      ;;
    P)
      applicationPath=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ $readMissingFromSTDIN = 1 ]
then
    if [ "x$ftpHost" = "x" ]
    then
        read -p "Ftp host: " ftpHost
    fi
    if [ "x$ftpUser" = "x" ]
    then
        read -p "Ftp username: " ftpUser
    fi
    if [ "x$ftpPassword" = "x" ]
    then
        #disable stdin
        stty -echo
        read -p "Ftp password: " ftpPassword; echo
        #enable stdin
        stty echo
    fi
    if [ "x$applicationPath" = "x" ]
    then
        read -p "Project path: " applicationPath
    fi
else
    if [ "x$ftpHost" = "x" ] || [ "x$ftpUser" = "x" ] || [ "x$ftpPassword" = "x" ] || [ "x$applicationPath" = "x" ]
    then
        echo "Some vars are missing, try -h option to get some help" >&2
    fi
fi


#go in the project
cd $applicationPath

#check if is git project (if is file .git/config)
if [ ! -f .git/config ]
then
    echo "Not a git project !"
    exit
fi

#stash not commited work
echo "Stash current work"
git stash

lastTag=$(git tag | xargs -I T git log -n 1 --format='%at T' T | sort | awk '{print $2}' | tail -n 1)

doneWorkSinceLastTag=$(git diff $lastTag --stat --name-only)

if [ "x$doneWorkSinceLastTag" = "x" ]
then
    echo "Nothing to do"
else
    echo "--------------------------------------"
    echo "Files which will be send :"
    files=""
    for i in $doneWorkSinceLastTag
    do
        if [ -f $i ] || [ -d $i ]
        then
            #updated/new file, put it to the ftp
            ftpCmd="put"
        else
            #deleted file, remove it from the ftp
            ftpCmd="delete"
        fi

        echo $i $ftpCmd

        read whatToDo

        if [ $whatToDo = "Y" ]
        then
            #send current file to ftp
            ftp -vin $ftpHost <<EOF
            binary
            user $ftpUser $ftpPassword
            $ftpCmd $i
            bye
EOF
        fi
    done

    echo "--------------------------------------"
    echo "Files sent"

    echo "Last tag was $lastTag"
    echo "New tag name (leave empty if no tag creation) :"
    read newTag

    if [ $newTag = $lastTag ]
    then
        echo "Updating previous tag"
        git tag -f $newTag
        git push --tags
    elif [ "x$newTag" != "x" ]
    then
        echo "Creation of a new tag"
        git tag $newTag
        git push --tags
    fi
fi

echo "Restore stashed work"
git stash pop

echo "Done !"
