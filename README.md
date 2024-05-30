# gpt-cmd

> Sit back and let ChatGPT figure out what commands need to be run

> [!WARNING]
> It's always risky to execute commands directly from a third party. Use responsibly and at your own risk.

```sh
gpt_cmd "Install python3 and pip3 and symlink them to python and pip"

gpt_cmd "You're running on an alpine linux distro that already has wget and bash installed. Install kafka"

gpt_cmd "Install SQLite and write a script to verify it's working correctly"
```

### Problem

> I'm working on a fresh Docker image, and I can't remember the specific commands needed to install tools. I can ask ChatGPT, but it might give me an answer that doesn't work with the exact environment I'm running in (e.g. differences between linux distros). Why can't ChatGPT just figure all that out for me?

The main problem is that, a lot of the time, to determine what exactly needs to be run (e.g. to install kafka in a Docker image), you need to try running commands to see if they fail, or run commands to probe the system to determine what tools are available.

For example, sometimes `sudo` doesn't exist in Docker, and since it runs as the root user by default, you can just leave it out. ChatGPT has no problem deducing that it can just remove the `sudo` in those cases.

### Solution

Let ChatGPT iteratively run commands for you to achieve your end goal.

The way it works is that you provide some end goal (e.g. 'Install python3 and pip3'), and ChatGPT will respond with a list of commands it wants to run. The tool will execute these commands and respond to ChatGPT with the stdout and exit code of each. Once ChatGPT thinks it's done, it'll respond accordingly and the loop will end.

With this approach, ChatGPT is able to probe your system and try running commands, responding to potential failures as they happen with alternative commands.

## Install

> [!WARNING]
> In light of my other warning above, this install script is pulled directly from my GitHub repo, and is a potential vulnerability if the repo (or GitHub) becomes compromised. Always inspect scripts for shady behavior before running them on your device (even mine: [install.sh](https://raw.githubusercontent.com/chrisdothtml/gpt-cmd/main/install.sh)).

**NOTE**: the install script and tool require: `python` (v3), `bash`, and either `curl` or `wget`

```sh
curl -s https://raw.githubusercontent.com/chrisdothtml/gpt-cmd/main/install.sh | bash

# or if you prefer wget
wget -qO- https://raw.githubusercontent.com/chrisdothtml/gpt-cmd/main/install.sh | bash
```

See [Env var overrides](#env-var-overrides) section for changing the install dir.

The install script will write to your `.profile` file to expose it to your `$PATH`, but if that doesn't work, you'll have to manually add it your path:

```sh
# replace `$HOME` with your custom install dir if you used one
export PATH="$HOME/gpt_cmd/bin:$PATH"
```

## Use

Before running, you need to create an `~/OPENAI_TOKEN` file and put your token in it.

```sh
gpt_cmd <goal>

# see `Env var overrides` section below for full list
GPT_CMD_MODEL="gpt-4-turbo" gpt_cmd <goal>
GPT_CMD_TOKEN_FILE_PATH="/my/token/file" gpt_cmd <goal>

# print path to the dir containing message logs for your previous runs
gpt_cmd --get-convos-dir
```

The `goal` can be literally anything you can achieve via a terminal (which is a lot). Even if it takes dozens of commands to get there, it'll eventually get there (maybe). You can be as descriptive or vague as you want, and list as many different tasks as you want (e.g. 'Install [some tool] and then write a starter script with some examples of how to use it').

## Env var overrides

Enironment vars that you can provide to change the behavior of the tool.

### `GPT_CMD_INSTALL_DIR`

Override the dir the installer puts the tool in.

**Default**: home dir

**Example**:

```sh
curl -s [...] | GPT_CMD_INSTALL_DIR="/my/custom/dir" bash
```

### `GPT_CMD_MODEL`

Override the gpt model used by the tool.

**Default**: `gpt-4o`

### `GPT_CMD_TOKEN_FILE_PATH`

Override the file path the tool gets your OpenAI token from.

**Default**: `~/OPENAI_TOKEN`

### `GPT_CMD_DANGEROUSLY_SKIP_PROMPTS`

By default, the tool will prompt you before running each command, as giving an AI unfettered access to run commands on your system is usually a bad idea. However, if you're on a throwaway machine/container and don't care what happens to it, you can disable the prompts via `GPT_CMD_DANGEROUSLY_SKIP_PROMPTS=true`.

## License

[MIT](license)
