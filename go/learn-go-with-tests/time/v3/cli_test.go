package poker_test

import (
	"bytes"
	"io"
	"strconv"
	"strings"
	"testing"

	poker "github.com/cedrickchee/learn-go-with-tests/time/v3"
)

var dummyBlindAlerter = &poker.SpyBlindAlerter{}
var dummyPlayerStore = &poker.StubPlayerStore{}
var dummyStdIn = &bytes.Buffer{}
var dummyStdOut = &bytes.Buffer{}

type GameSpy struct {
	StartCalledWith  int
	FinishCalledWith string
	StartCalled      bool
	FinishedCalled   bool
}

func (g *GameSpy) Start(numberOfPlayers int) {
	g.StartCalled = true
	g.StartCalledWith = numberOfPlayers
}

func (g *GameSpy) Finish(winner string) {
	g.FinishedCalled = true
	g.FinishCalledWith = winner
}

func userSends(messages ...string) io.Reader {
	return strings.NewReader(strings.Join(messages, "\n"))
}

func TestCLI(t *testing.T) {
	t.Run("start game with 3 players and finish game with 'David' as winner", func(t *testing.T) {
		numberOfPlayers := 3

		stdout := &bytes.Buffer{}
		in := userSends(strconv.Itoa(numberOfPlayers), "David wins")

		game := &GameSpy{}

		cli := poker.NewCLI(in, stdout, game)
		cli.PlayPoker()

		assertMessagesSentToUser(t, stdout, poker.PlayerPrompt)
		assertGameStartedWith(t, game, numberOfPlayers)
		assertFinishCalledWith(t, game, "David")
	})

	t.Run("start game with 8 players and record 'Oliver' as winner", func(t *testing.T) {
		numberOfPlayers := 8
		in := userSends(strconv.Itoa(numberOfPlayers), "Oliver wins")

		game := &GameSpy{}

		cli := poker.NewCLI(in, dummyStdOut, game)
		cli.PlayPoker()

		assertGameStartedWith(t, game, numberOfPlayers)
		assertFinishCalledWith(t, game, "Oliver")
	})

	t.Run("it prints an error when a non numeric value is entered and does not start the game", func(t *testing.T) {
		stdout := &bytes.Buffer{}

		in := userSends("Pies")

		game := &GameSpy{}

		cli := poker.NewCLI(in, stdout, game)
		cli.PlayPoker()

		assertGameNotStarted(t, game)
		assertMessagesSentToUser(t, stdout, poker.PlayerPrompt, poker.BadPlayerInputErrMsg)
	})

	t.Run("it prints an error when the winner is declared incorrectly", func(t *testing.T) {
		stdout := &bytes.Buffer{}

		in := userSends("8", "Lloyd is a killer")

		game := &GameSpy{}

		cli := poker.NewCLI(in, stdout, game)
		cli.PlayPoker()

		assertGameNotFinished(t, game)
		assertMessagesSentToUser(t, stdout, poker.PlayerPrompt, poker.BadWinnerInputMsg)
	})
}

func assertScheduledAlert(t *testing.T, got, want poker.ScheduledAlert) {
	t.Helper()

	if got != want {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func assertMessagesSentToUser(t *testing.T, stdout *bytes.Buffer, messages ...string) {
	t.Helper()

	got := stdout.String()
	want := strings.Join(messages, "")

	if got != want {
		t.Errorf("got %q sent to stdout but expected %+v", got, messages)
	}
}

func assertFinishCalledWith(t *testing.T, game *GameSpy, winner string) {
	t.Helper()

	if game.FinishCalledWith != winner {
		t.Errorf("expected finish called with %q but got %q", winner, game.FinishCalledWith)
	}
}

func assertGameNotStarted(t *testing.T, game *GameSpy) {
	t.Helper()

	if game.StartCalled {
		t.Errorf("game should not have started")
	}
}

func assertGameStartedWith(t *testing.T, game *GameSpy, numberOfPlayersWanted int) {
	t.Helper()

	if game.StartCalledWith != numberOfPlayersWanted {
		t.Errorf("wanted Start called with %d but got %d", numberOfPlayersWanted, game.StartCalledWith)
	}
}

func assertGameNotFinished(t *testing.T, game *GameSpy) {
	t.Helper()

	if game.FinishedCalled {
		t.Errorf("game should not have finished")
	}
}
