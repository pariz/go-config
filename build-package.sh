#!/bin/bash

echo "Downloading latest Atom release..."
ATOM_CHANNEL="${ATOM_CHANNEL:=stable}"

if [ "$TRAVIS_OS_NAME" == "osx" ]; then
    curl -s -L "https://atom.io/download/mac?channel=$ATOM_CHANNEL" \
      -H 'Accept: application/octet-stream' \
      -o "atom.zip"
    ATOM_DOWNLOAD_URL="https://atom.io/download/mac?channel=$ATOM_CHANNEL"
    mkdir atom
    unzip -q atom.zip -d atom
    if [ "$ATOM_CHANNEL" == "stable" ]; then
      export ATOM_APP_NAME="Atom.app"
      export ATOM_SCRIPT_NAME="atom.sh"
      export ATOM_SCRIPT_PATH="./atom/${ATOM_APP_NAME}/Contents/Resources/app/atom.sh"
    else
      export ATOM_CHANNEL_CAMELCASE="$(tr '[:lower:]' '[:upper:]' <<< ${ATOM_CHANNEL:0:1})${ATOM_CHANNEL:1}"
      export ATOM_APP_NAME="Atom ${ATOM_CHANNEL_CAMELCASE}.app"
      export ATOM_SCRIPT_NAME="atom-${ATOM_CHANNEL}"
      export ATOM_SCRIPT_PATH="./atom-${ATOM_CHANNEL}"
      ln -s "./atom/${ATOM_APP_NAME}/Contents/Resources/app/atom.sh" "${ATOM_SCRIPT_PATH}"
    fi
    export PATH="$PWD/atom/${ATOM_APP_NAME}/Contents/Resources/app/apm/bin:$PATH"
    export ATOM_PATH="./atom"
    export APM_SCRIPT_PATH="./atom/${ATOM_APP_NAME}/Contents/Resources/app/apm/node_modules/.bin/apm"
else
    curl -s -L "https://atom.io/download/deb?channel=$ATOM_CHANNEL" \
      -H 'Accept: application/octet-stream' \
      -o "atom.deb"
    /sbin/start-stop-daemon --start --quiet --pidfile /tmp/custom_xvfb_99.pid --make-pidfile --background --exec /usr/bin/Xvfb -- :99 -ac -screen 0 1280x1024x16
    export DISPLAY=":99"
    sudo apt-get update -qq
    sudo gdebi -n atom.deb
    if [ "$ATOM_CHANNEL" == "stable" ]; then
      export ATOM_SCRIPT_NAME="atom"
      export APM_SCRIPT_NAME="apm"
    else
      export ATOM_SCRIPT_NAME="atom-$ATOM_CHANNEL"
      export APM_SCRIPT_NAME="apm-$ATOM_CHANNEL"
    fi
    export ATOM_SCRIPT_PATH="/usr/bin/$ATOM_SCRIPT_NAME"
    export APM_SCRIPT_PATH="/usr/bin/$APM_SCRIPT_NAME"
fi


echo "Using Atom version:"
"$ATOM_SCRIPT_PATH" -v
echo "Using APM version:"
"$APM_SCRIPT_PATH" -v

echo "Downloading package dependencies..."
"$APM_SCRIPT_PATH" clean
"$APM_SCRIPT_PATH" install

TEST_PACKAGES="${APM_TEST_PACKAGES:=none}"

if [ "$TEST_PACKAGES" != "none" ]; then
  echo "Installing atom package dependencies..."
  for pack in $TEST_PACKAGES ; do
    "$APM_SCRIPT_PATH" install $pack
  done
fi

if [ -f ./node_modules/.bin/coffeelint ]; then
  if [ -d ./lib ]; then
    echo "Linting package..."
    ./node_modules/.bin/coffeelint lib
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi
  if [ -d ./spec ]; then
    echo "Linting package specs..."
    ./node_modules/.bin/coffeelint spec
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi
fi

if [ -f ./node_modules/.bin/eslint ]; then
  if [ -d ./lib ]; then
    echo "Linting package..."
    ./node_modules/.bin/eslint lib
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi
  if [ -d ./spec ]; then
    echo "Linting package specs..."
    ./node_modules/.bin/eslint spec
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi
fi

if [ -f ./node_modules/.bin/standard ]; then
  if [ -d ./lib ]; then
    echo "Linting package..."
    ./node_modules/.bin/standard lib/**/*.js
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi
  if [ -d ./spec ]; then
    echo "Linting package specs..."
    ./node_modules/.bin/standard spec/**/*.js
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi
fi

echo "Running specs..."
"$ATOM_SCRIPT_PATH" --test spec
exit
