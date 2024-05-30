import datetime
import json
import os
import subprocess
import sys
from openai import OpenAI

def ensure_dir(directory):
  if not os.path.exists(directory):
    os.makedirs(directory, exist_ok=True)

def read_file(file_path):
  with open(file_path, 'r') as file:
    return file.read().strip()

def write_file(file_path, content):
  with open(file_path, 'w') as file:
    file.write(content)

# runtime options
OPTIONS = {
  'dangerously_skip_prompts': os.environ.get('GPT_CMD_DANGEROUSLY_SKIP_PROMPTS') == 'true',
  'model': os.environ.get('GPT_CMD_MODEL', 'gpt-4o'),
  'token_file_path': os.environ.get(
    'GPT_CMD_TOKEN_FILE_PATH',
    os.path.join(os.path.expanduser('~'), 'OPENAI_TOKEN'),
  ),
}

# trust path provided by entrypoint bash script over `__file__`,
# which can be a relative path in some cases
PROJECT_ROOT_DIR = os.path.normpath(
  os.environ.get('GPT_CMD_PROJECT_ROOT', os.path.dirname(__file__))
)
CONVOS_DIR = os.path.join(PROJECT_ROOT_DIR, '.convos')
SYSTEM_PROMPT = read_file(os.path.join(PROJECT_ROOT_DIR, 'system-prompt.txt'))
OPENAI_CLIENT = None

class ansi:
  '''
    Convenience methods for wrapping text with ansi colors
  '''

  _blue = '\033[94m'
  _dim = '\033[2m'
  _green = '\033[92m'
  _red = '\033[91m'
  _reset = '\033[0m'

  @staticmethod
  def color_text(text, color):
    return '\n'.join(f"{color}{line}{ansi._reset}" for line in str(text).splitlines())

  @staticmethod
  def blue(text):
    return ansi.color_text(text, ansi._blue)

  @staticmethod
  def dim(text):
    return ansi.color_text(text, ansi._dim)

  @staticmethod
  def green(text):
    return ansi.color_text(text, ansi._green)

  @staticmethod
  def red(text):
    return ansi.color_text(text, ansi._red)

def call_gpt(messages):
  if OPENAI_CLIENT is None:
    OPENAI_CLIENT = OpenAI(api_key=read_file(OPTIONS['token_file_path']))

  response = OPENAI_CLIENT.chat.completions.create(
    model=OPTIONS['model'],
    response_format={ "type": "json_object" },
    messages=messages,
  )
  return response.choices[0].message.content

def exec_cmd(command):
  result = subprocess.run(
    command,
    shell=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True
  )
  return result.stdout.strip(), result.returncode

def clear_prev_line():
  sys.stdout.write('\x1b[1A')
  sys.stdout.write('\x1b[2K')
  sys.stdout.flush()

def prompt_user_yn(prompt):
  index = 0
  while True:
    if index > 0:
      clear_prev_line()

    response = input(f'{prompt} (Y/n) ').strip().lower()
    if response in ['y', 'n', '']:
      return response == 'y' or response == ''
    index += 1

def main(goal):
  convo_timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
  convo_file_name = None
  messages = [
    {"role": "system", "content": SYSTEM_PROMPT},
    {"role": "user", "content": goal}
  ]

  def save_convo():
    file_name = convo_timestamp
    if convo_file_name is not None:
      file_name = f'{convo_file_name}_{convo_timestamp}'
    file_name += '.json'

    file_path = os.path.join(CONVOS_DIR, file_name)
    ensure_dir(CONVOS_DIR)
    write_file(file_path, json.dumps(messages, indent=2))

  print(f"{ansi.blue('Goal:')} {goal}")
  while True:
    raw_response = call_gpt(messages)
    messages.append({"role": "assistant", "content": raw_response})
    response = json.loads(raw_response)

    if convo_file_name is None and len(response.get('convo-file-name', '')) > 0:
      convo_file_name = f"{response['convo-file-name']}_{convo_timestamp}"

    print('\n----------')

    if isinstance(response.get('status'), str):
      was_success = response['status'] == 'success'

      if was_success:
        print(ansi.green('✅ Goal successfully achieved.'))
      else:
        print(ansi.red('❌ Goal failed.'))

      if isinstance(response.get('context'), str):
        print(response['context'])

      save_convo()
      exit(0 if was_success else 1)

    if isinstance(response.get('context'), str):
      print(f"{ansi.blue('Context:')} {response['context']}")

    if isinstance(response.get('commands'), list):
      cmd_results = []
      for index, cmd in enumerate(response['commands']):
        if index > 0:
          print('')

        print(f"{ansi.blue('Command:')} {ansi.dim(cmd)}")
        if not OPTIONS['dangerously_skip_prompts']:
          if prompt_user_yn('OK to run command?'):
            clear_prev_line()
          else:
            save_convo()
            exit(1)
        stdout, exit_code = exec_cmd(cmd)

        cmd_ansi_color = ansi.green if exit_code == 0 else ansi.red
        print(f"{cmd_ansi_color('Exit code:')} {ansi.dim(exit_code)}")
        print(ansi.dim(stdout))
        cmd_results.append({"command": "cmd", "stdout": stdout, "exit_code": exit_code})

        if exit_code != 0:
          break

      messages.append({"role": "user", "content": json.dumps(cmd_results)})
    else:
      print(ansi.red('ERROR: No further commands provided, and no success/failure signal was provided'))
      save_convo()
      exit(1)

if __name__ == "__main__":
  helptext = 'Usage:\ngpt_cmd <goal>\ngpt_cmd --get-convos-dir'

  if len(sys.argv) != 2:
    print(helptext)
    sys.exit(1)

  if sys.argv[1] == '--help':
    print(helptext)
    exit(0)

  if sys.argv[1] == '--get-convos-dir':
    print(CONVOS_DIR)
    exit(0)

  goal = sys.argv[1]
  main(goal)
