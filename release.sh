#!/usr/bin/env bash

# install deps into `vendor` dir and zip it up into a tarball for the repo
pip install --target=vendor -r <(pipenv requirements)
tar -czf ./vendor.tar.gz vendor
rm -rf ./vendor
