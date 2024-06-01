package cmd

import (
	"context"

	openai "github.com/sashabaranov/go-openai"
)

var OPENAI_CLIENT *openai.Client

type ChatMessage = openai.ChatCompletionMessage

func GetGPTResponse(messages []ChatMessage, model string, token string) string {
	if OPENAI_CLIENT == nil {
		OPENAI_CLIENT = openai.NewClient(token)
	}

	resp, err := OPENAI_CLIENT.CreateChatCompletion(
		context.Background(),
		openai.ChatCompletionRequest{
			Model:    model,
			Messages: messages,
			ResponseFormat: &openai.ChatCompletionResponseFormat{
				Type: "json_object",
			},
		},
	)
	if err != nil {
		panic(err)
	}

	return resp.Choices[0].Message.Content
}
