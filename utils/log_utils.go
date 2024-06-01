package utils

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type Ansi struct{}

const (
	blue  = "\033[94m"
	dim   = "\033[2m"
	green = "\033[92m"
	red   = "\033[91m"
	reset = "\033[0m"
)

func (a Ansi) colorText(text, color string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		lines[i] = color + line + reset
	}
	return strings.Join(lines, "\n")
}

func (a Ansi) Blue(text string) string {
	return a.colorText(text, blue)
}

func (a Ansi) Dim(text string) string {
	return a.colorText(text, dim)
}

func (a Ansi) Green(text string) string {
	return a.colorText(text, green)
}

func (a Ansi) Red(text string) string {
	return a.colorText(text, red)
}

func ClearPrevLine() {
	fmt.Print("\033[1A")
	fmt.Print("\033[2K")
}

func PromptUserYN(prompt string) bool {
	reader := bufio.NewReader(os.Stdin)
	index := 0

	for {
		if index > 0 {
			ClearPrevLine()
		}

		fmt.Printf("%s (Y/n) ", prompt)
		response, _ := reader.ReadString('\n')
		response = strings.TrimSpace(strings.ToLower(response))

		if response == "y" || response == "n" || response == "" {
			return response == "y" || response == ""
		}

		index++
	}
}
