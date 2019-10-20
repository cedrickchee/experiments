package poker_test

import (
	"strings"
	"testing"

	poker "github.com/cedrickchee/learn-go-with-tests/command-line/v3"
)

func TestCLI(t *testing.T) {
	t.Run("record david win from user input", func(t *testing.T) {
		in := strings.NewReader("David wins\n")

		playerStore := &poker.StubPlayerStore{}
		cli := poker.NewCLI(playerStore, in)
		cli.PlayPoker()

		poker.AssertPlayerWin(t, playerStore, "David")
	})

	t.Run("record oliver win from user input", func(t *testing.T) {
		in := strings.NewReader("Oliver wins\n")

		playerStore := &poker.StubPlayerStore{}
		cli := poker.NewCLI(playerStore, in)
		cli.PlayPoker()

		poker.AssertPlayerWin(t, playerStore, "Oliver")
	})
}
