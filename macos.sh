#!/bin/zsh

requeststatus() { # $1: requestUUID
    requestUUID=${1?:"need a request UUID"}
    req_status=$(xcrun altool --notarization-info "$requestUUID" \
                              --username "$APPLE_ID" \
                              --password "$APPLE_APP_PASSWORD" 2>&1 \
                 | awk -F ': ' '/Status:/ { print $2; }' )
    echo "$req_status"
}

notarizefile() { # $1: path to file to notarize, $2: identifier
    filepath=${1:?"need a filepath"}
    
    # upload file
    echo "## uploading $filepath for notarization"
    requestUUID=$(xcrun altool --notarize-app \
                               --primary-bundle-id "link.studio.standalone.zip" \
                               --username "$APPLE_ID" \
                               --password "$APPLE_APP_PASSWORD" \
			       --asc-provider "CX34XZ2JTT" \
                               --file "$filepath" 2>&1 \
                  | awk '/RequestUUID/ { print $NF; }')
                               
    echo "Notarization RequestUUID: $requestUUID"
    
    if [[ $requestUUID == "" ]]; then 
        echo "could not upload for notarization"
        exit 1
    fi
        
    # wait for status to be not "in progress" any more
    request_status="in progress"
    while [[ "$request_status" == "in progress" ]]; do
        echo -n "waiting... "
        sleep 10
        request_status=$(requeststatus "$requestUUID")
        echo "$request_status"
    done
    
    # print status information
    xcrun altool --notarization-info "$requestUUID" \
                 --username "$APPLE_ID" \
                 --password "$APPLE_APP_PASSWORD"
    echo 
    
    if [[ $request_status != "success" ]]; then
        echo "## could not notarize $filepath"
        exit 1
    fi
    
}

curl -o studio-link-standalone-osx.zip https://download.studio.link/releases/$APPVEYOR_REPO_TAG_NAME/osx/studio-link-standalone-hardened-$APPVEYOR_REPO_TAG_NAME.zip
#notarizefile "studio-link-standalone-osx.zip"
unzip studio-link-standalone-osx.zip
xcrun stapler staple "StudioLinkStandaloneHardened.app"
zip -r studio-link-standalone-notarized-$APPVEYOR_REPO_TAG_NAME.zip StudioLinkStandaloneHardened.app

appveyor PushArtifact studio-link-standalone-notarized-$APPVEYOR_REPO_TAG_NAME.zip
