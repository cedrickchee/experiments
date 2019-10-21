package poker_test

import (
	"bytes"
	"strings"
	"testing"

	poker "github.com/cedrickchee/learn-go-with-tests/time/v2"
)

var dummyBlindAlerter = &poker.SpyBlindAlerter{}
var dummyPlayerStore = &poker.StubPlayerStore{}
var dummyStdIn = &bytes.Buffer{}
var dummyStdOut = &bytes.Buffer{}

type GameSpy struct {
	StartCalledWith  int
	FinishCalledWith string
	StartCalled      bool
}

func (g *GameSpy) Start(numberOfPlayers int) {
	g.StartCalledWith = numberOfPlayers
	g.StartCalled = true
}

func (g *GameSpy) Finish(winner string) {
	g.FinishCalledWith = winner
}

func TestCLI(t *testing.T) {
	t.Run("record 'David' win from user input", func(t *testing.T) {
		in := strings.NewReader("1\nDavid wins\n")

		game := &GameSpy{}

		cli := poker.NewCLI(in, dummyStdOut, game)
		cli.PlayPoker()

		if game.FinishCalledWith != "David" {
			t.Errorf("expected finish called with 'David' but got %q", game.FinishCalledWith)
		}
	})

	t.Run("finish game with 'Oliver' as winner", func(t *testing.T) {
		in := strings.NewReader("1\nOliver wins\n")

		game := &GameSpy{}

		cli := poker.NewCLI(in, dummyStdOut, game)
		cli.PlayPoker()

		if game.FinishCalledWith != "Oliver" {
			t.Errorf("expected finish called with 'David' but got %q", game.FinishCalledWith)
		}
	})

	t.Run("it prompts the user to enter the number of players and starts the game", func(t *testing.T) {
		stdout := &bytes.Buffer{}
		in := strings.NewReader("7\n")

		game := &GameSpy{}

		cli := poker.NewCLI(in, stdout, game)
		cli.PlayPoker()

		gotPrompt := stdout.String()
		wantPrompt := poker.PlayerPrompt

		if gotPrompt != wantPrompt {
			t.Errorf("got %q, want %q", gotPrompt, wantPrompt)
		}

		if game.StartCalledWith != 7 {
			t.Errorf("wanted Start called with 7 but got %d", game.StartCalledWith)
		}
	})
}

func assertScheduledAlert(t *testing.T, got, want poker.ScheduledAlert) {
	t.Helper()

	if got != want {
		t.Errorf("got %+v, want %+v", got, want)
	}
}
