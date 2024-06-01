package cmd

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"gpt_cmd/utils"

	dedent "github.com/lithammer/dedent"
)

//go:embed system_prompt.txt
var SYSTEM_PROMPT string

var PROJECT_FILES_DIR = filepath.Join(utils.GetHomeDir(), ".gpt_cmd")
var CONVOS_DIR = filepath.Join(PROJECT_FILES_DIR, ".convos")
var ansi = utils.Ansi{}

type RuntimeOptions struct {
	DangerouslySkipPrompts bool
	Model                  string
	APIToken               string
}

type GPTResponse struct {
	Commands      []string `json:"commands"`
	Context       string   `json:"context"`
	ConvoFileName string   `json:"convo-file-name"`
	Status        string   `json:"status"`
}

func RunLoop(goal string, opts *RuntimeOptions) {
	systemInfo := fmt.Sprintf("System info:\nOS: %s\nArchitecture: %s", runtime.GOOS, runtime.GOARCH)
	messages := []ChatMessage{
		{
			Role:    "system",
			Content: SYSTEM_PROMPT,
		},
		{
			Role:    "user",
			Content: fmt.Sprintf("%s\n%s", goal, systemInfo),
		},
	}

	convoTimestamp := time.Now().Format("2006-01-02_15-04-05")
	var convoFileName *string

	// used to progressively update the local file for this convo
	saveConvo := func() {
		fileName := convoTimestamp
		if convoFileName != nil {
			fileName = fmt.Sprintf("%s_%s", *convoFileName, convoTimestamp)
		}
		fileName += ".json"

		filePath := filepath.Join(CONVOS_DIR, fileName)
		utils.EnsureDir(CONVOS_DIR)
		utils.WriteFile(filePath, utils.JsonStringify(messages, true))
	}

	fmt.Printf("%s %s\n", ansi.Blue("Goal:"), goal)
	for {
		fmt.Println("\n----------")

		// In each iteration, call GPT with the latest messages thread
		rawResponse := GetGPTResponse(messages, opts.Model, opts.APIToken)
		// Add GPT's response to the messages thread
		messages = append(messages, ChatMessage{
			Role:    "assistant",
			Content: rawResponse,
		})
		var response GPTResponse
		json.Unmarshal([]byte(rawResponse), &response)

		if convoFileName == nil && response.ConvoFileName != "" {
			convoFileName = &response.ConvoFileName
		}

		// If `status` prop is provided, it means GPT determined the
		// goal is completed. Report the status and print any context
		// the GPT provided
		if response.Status != "" {
			wasSuccess := response.Status == "success"

			if wasSuccess {
				fmt.Println(ansi.Green("✅ Goal successfully achieved."))
			} else {
				fmt.Println(ansi.Red("❌ Goal failed."))
			}

			if response.Context != "" {
				fmt.Println(response.Context)
			}

			saveConvo()
			if wasSuccess {
				os.Exit(0)
			} else {
				os.Exit(1)
			}
		}

		if len(response.Commands) > 0 {
			// This use of the `context` prop is for the GPT to provide
			// info about the command(s) it's running
			if response.Context != "" {
				fmt.Printf("%s %s\n", ansi.Blue("Context:"), response.Context)
			}

			var cmdResults []map[string]interface{}
			for index, cmd := range response.Commands {
				if index > 0 {
					fmt.Println("")
				}

				fmt.Printf("%s %s\n", ansi.Blue("Command:"), ansi.Dim(cmd))
				if !opts.DangerouslySkipPrompts {
					if utils.PromptUserYN("OK to run command?") {
						utils.ClearPrevLine()
					} else {
						// User didn't want to run command, so save convo and exit
						saveConvo()
						os.Exit(1)
					}
				}

				stdout, exitCode := utils.ExecCmd(cmd)

				var exitCodeText = "Exit code:"
				if exitCode == 0 {
					exitCodeText = ansi.Green(exitCodeText)
				} else {
					exitCodeText = ansi.Red(exitCodeText)
				}
				fmt.Printf("%s %s\n", exitCodeText, ansi.Dim(fmt.Sprint(exitCode)))
				if len(stdout) > 0 {
					fmt.Println(ansi.Dim(stdout))
				}

				cmdResults = append(cmdResults, map[string]interface{}{
					"command":   cmd,
					"stdout":    stdout,
					"exit_code": exitCode,
				})

				if exitCode != 0 {
					break
				}
			}

			// Add new message with the result(s) of the command(s)
			messages = append(messages, ChatMessage{
				Role:    "user",
				Content: utils.JsonStringify(cmdResults, false),
			})
		} else {
			fmt.Println(ansi.Red("ERROR: No further commands provided, and no success/failure status was provided by GPT"))
			saveConvo()
			os.Exit(1)
		}
	}
}

func Execute() {
	helpText := strings.TrimSpace(dedent.Dedent(`
    Usage:
    gpt_cmd <goal>
    gpt_cmd --get-convos-dir
    gpt_cmd --help, -h

    Environment vars:
    GPT_CMD_DANGEROUSLY_SKIP_PROMPTS [true]
    GPT_CMD_MODEL [string] (Default: gpt-4o)
    GPT_CMD_TOKEN [string]
    GPT_CMD_TOKEN_FILE_PATH [string] (Default: ~/OPENAI_TOKEN)
  `))

	if len(os.Args) != 2 || os.Args[1] == "" {
		fmt.Println(helpText)
		os.Exit(1)
	}

	if os.Args[1] == "--help" || os.Args[1] == "-h" {
		fmt.Println(helpText)
		os.Exit(0)
	}

	if os.Args[1] == "--get-convos-dir" {
		fmt.Println(CONVOS_DIR)
		os.Exit(0)
	}

	// unrecognized arg passed in
	if strings.HasPrefix(os.Args[1], "--") {
		fmt.Println(helpText)
		os.Exit(1)
	}

	var options = RuntimeOptions{
		DangerouslySkipPrompts: utils.GetEnv("GPT_CMD_DANGEROUSLY_SKIP_PROMPTS", "") == "true",
		Model:                  utils.GetEnv("GPT_CMD_MODEL", "gpt-4o"),
		APIToken:               "",
	}

	token := utils.GetEnv("GPT_CMD_TOKEN", "")
	if token == "" {
		tokenFilePath := utils.GetEnv(
			"GPT_CMD_TOKEN_FILE_PATH",
			filepath.Join(utils.GetHomeDir(), "OPENAI_TOKEN"),
		)

		if data, err := os.ReadFile(tokenFilePath); err == nil {
			token = strings.TrimSpace(string(data))
		}
	}
	options.APIToken = token

	if options.APIToken == "" {
		fmt.Println(ansi.Red("ERROR: Unable to resolve an OpenAI token\n"))
		fmt.Println(helpText)
		os.Exit(1)
	}

	RunLoop(os.Args[1], &options)
}
