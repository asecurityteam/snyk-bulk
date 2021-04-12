#!/bin/bash

# source common functions

# source 'snyk-scan/common.sh'

# declare -x CUSTOM_REPO='https://gitlab.com/cmbarker/pythonfiles'
declare -x JSON_STASH="/tmp/json"

# declare -x TARGET=$1
declare -x TARGET="/project"

customPrep(){
    /bin/bash .snyk.d/prep.sh
}

scanJavascript()
{ 
    PATH_TO_MANIFEST=$1
    echo "path to manifest: ${PATH_TO_MANIFEST}" >&2
    DIR_NAME=$(dirname $PATH_TO_MANIFEST)
    
    # the file to provide as an argument to snyk test/monitor
    # could be different. for example, --file=yarn.lock, even
    # though our initial detection is for package.json.  
    # the prepJavascript function will return the name of the file
    # to provide to the snyk/test monitor command
    #
    # prep enviroment for a successful subsequent snyk scan
    MANIFEST_NAME=$(prepJavascript "${PATH_TO_MANIFEST}")
    echo "manifest name: ${MANIFEST_NAME}" >&2

    # Run snyk monitor with specified manifest as workaround to avoid other manifest type
    cd $DIR_NAME
    echo "In directory: " $(pwd) >&2
    snyk monitor --file="${MANIFEST_NAME}"  --remote-repo-url="${DIR_NAME}" --json | tee -a $JSON_STASH
    cd $HOME
}

prepJavascript(){
    PATH_TO_MANIFEST=$1
    MANIFEST_NAME=$(basename "${PATH_TO_MANIFEST}")
    DIR_NAME=$(dirname "${PATH_TO_MANIFEST}")
    
    cd $DIR_NAME
    # echo "changed directory to " $(pwd)
    
    if [ -f ".snyk.d/prep.sh" ]
    then
        customPrep
    else
        if [ -d "node_modules" ]; then
            echo "Found node_modules folder" >&2
            MANIFEST_NAME="package.json"
        elif [ -f "yarn.lock" ]; then
            echo "Found package.json & yarn.lock" >&2
            MANIFEST_NAME="yarn.lock"
            #out=$(yarn install)
        elif [ -f "package-lock.json" ]; then
            echo "Found package.json & package-lock.json" >&2
            MANIFEST_NAME="package-lock.json"
            #out=$(npm install)
        else
            echo "only package.json found,  must build dependency tree
            MANIFEST_NAME="package-lock.json"
            out=$(npm install)
        fi
    fi
    # cd $HOME
    echo "${MANIFEST_NAME}"
}

JS_FILES=($(find "${TARGET}" -type f -name "package.json" ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/submodules/*"))

echo "${JS_FILES[@]}"
if [ -n "${JS_FILES[0]}" ]
then
    for f in "${JS_FILES[@]}"
    do
        echo "$f"
        scanJavascript "${f}"
    done
else
    echo "No package.json files found"
fi
