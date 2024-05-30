# Contributing

## Running locally

First, install the dependencies (**note**: make sure you're using python 3 and pip 3):

```sh
# create virtual env
python -m venv env

# activate env
source env/bin/activate

# install deps
pip install -r requirements.txt
```

Now you can run the tool via:

```sh
python -m gpt_cmd [...]
```

## Cutting a release

Pushing a version tag (e.g. `v.1.0.0`) will trigger the [release.yml](.github/workflows/release.yml) GitHub action, which will build binaries for supported OSes and publish a release with them.

The binaries are generated using [pyinstaller](https://pyinstaller.org/en/stable/).
