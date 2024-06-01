# Contributing

## Running locally

First, install the dependencies (**note**: this was written with go v1.22.x):

```sh
go mod tidy
```

Now you can run the tool via:

```sh
go run main.go [...]
```

## Cutting a release

Pushing a version tag (e.g. `v1.0.0`) will trigger the [release.yml](.github/workflows/release.yml) GitHub workflow, which will build binaries for supported OSes and publish a release with them.
