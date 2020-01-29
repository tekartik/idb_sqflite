#!/usr/bin/env bash

# Must be ran from root (.travis.yml), will fail otherwise
set -ev

cd idb_sqflite_support
pub get
dart tool/travis.dart