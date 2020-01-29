#!/usr/bin/env bash

# Must be ran from root (.travis.yml), will fail otherwise
set -ev

pub get
pub run tekartik_travis_ci_flutter:install