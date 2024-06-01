package utils

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"os/user"
	"strings"
)

func GetHomeDir() string {
	usr, err := user.Current()
	if err != nil {
		panic(err)
	}
	return usr.HomeDir
}

func GetEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func EnsureDir(directory string) {
	if _, err := os.Stat(directory); os.IsNotExist(err) {
		os.MkdirAll(directory, os.ModePerm)
	}
}

func WriteFile(filePath, content string) {
	err := os.WriteFile(filePath, []byte(content), 0644)
	if err != nil {
		panic(err)
	}
}

func ExecCmd(command string) (string, int) {
	var out bytes.Buffer

	cmd := exec.Command("sh", "-c", command)
	cmd.Stdout = &out
	cmd.Stderr = &out
	err := cmd.Run()

	exitCode := 0
	if err != nil {
		exitCode = cmd.ProcessState.ExitCode()
	}

	return strings.TrimSpace(out.String()), exitCode
}

func JsonStringify(input interface{}, useIndent bool) string {
	var data []byte
	var err error

	if useIndent {
		data, err = json.MarshalIndent(input, "", "  ")
	} else {
		data, err = json.Marshal(input)
	}

	if err != nil {
		panic(err)
	}

	return string(data)
}
