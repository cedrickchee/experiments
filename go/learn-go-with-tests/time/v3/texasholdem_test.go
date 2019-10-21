package poker_test

import (
	"fmt"
	"testing"
	"time"

	poker "github.com/cedrickchee/learn-go-with-tests/time/v3"
)

func TestGame_Start(t *testing.T) {
	t.Run("schedules alerts on game start for 5 players", func(t *testing.T) {
		// in := strings.NewReader("David wins\n")

		// playerStore := &poker.StubPlayerStore{}

		blindAlerter := &poker.SpyBlindAlerter{}

		// game := poker.NewTexasHoldem(blindAlerter, playerStore)
		game := poker.NewTexasHoldem(blindAlerter, dummyPlayerStore)
		// cli := poker.NewCLI(in, dummyStdOut, game)
		// cli.PlayPoker()
		game.Start(5)

		cases := []poker.ScheduledAlert{
			{At: 0 * time.Second, Amount: 100},
			{At: 10 * time.Minute, Amount: 200},
			{At: 20 * time.Minute, Amount: 300},
			{At: 30 * time.Minute, Amount: 400},
			{At: 40 * time.Minute, Amount: 500},
			{At: 50 * time.Minute, Amount: 600},
			{At: 60 * time.Minute, Amount: 800},
			{At: 70 * time.Minute, Amount: 1000},
			{At: 80 * time.Minute, Amount: 2000},
			{At: 90 * time.Minute, Amount: 4000},
			{At: 100 * time.Minute, Amount: 8000},
		}

		checkSchedulingCases(t, cases, blindAlerter)
	})

	t.Run("schedules alerts on game start for 7 players", func(t *testing.T) {
		// stdout := &bytes.Buffer{}
		// in := strings.NewReader("7\n")
		blindAlerter := &poker.SpyBlindAlerter{}

		game := poker.NewTexasHoldem(blindAlerter, dummyPlayerStore)
		// cli := poker.NewCLI(in, stdout, game)
		// cli.PlayPoker()
		game.Start(7)

		// got := stdout.String()
		// want := poker.PlayerPrompt

		// if got != want {
		// 	t.Errorf("got %q, want %q", got, want)
		// }

		cases := []poker.ScheduledAlert{
			{At: 0 * time.Second, Amount: 100},
			{At: 12 * time.Minute, Amount: 200},
			{At: 24 * time.Minute, Amount: 300},
			{At: 36 * time.Minute, Amount: 400},
		}

		checkSchedulingCases(t, cases, blindAlerter)
	})
}

func TestGame_Finish(t *testing.T) {
	store := &poker.StubPlayerStore{}
	game := poker.NewTexasHoldem(dummyBlindAlerter, store)
	winner := "Julia"

	game.Finish(winner)
	poker.AssertPlayerWin(t, store, winner)
}

func checkSchedulingCases(t *testing.T, cases []poker.ScheduledAlert, blindAlerter *poker.SpyBlindAlerter) {
	t.Helper()

	for i, want := range cases {
		t.Run(fmt.Sprint(want), func(t *testing.T) {

			if len(blindAlerter.Alerts) <= i {
				t.Fatalf("alert %d was not scheduled %v", i, blindAlerter.Alerts)
			}

			got := blindAlerter.Alerts[i]
			assertScheduledAlert(t, got, want)
		})
	}
}
