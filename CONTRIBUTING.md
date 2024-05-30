# Contributing

## Running locally

First, install the dependencies (**note**: make sure you're using python 3 and pip 3):

```sh
# install pipenv
brew install pipenv

# install both runtime and dev dependencies
pipenv install --dev

# activate the virtual env
pipenv shell
```

Now you can run the tool via:

```sh
python -m gpt_cmd [...]
```

## Cutting a release

Currently this just updates the `vendor` tarball (only needed if deps were added/upgraded):

```sh
./release.sh
```

This script requires all the tools mentioned in the [Running locally](#running-locally) section.
