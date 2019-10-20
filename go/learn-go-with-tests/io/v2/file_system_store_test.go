package main

import (
	"strings"
	"testing"
)

func TestFileSystemStore(t *testing.T) {
	t.Run("/league from a render", func(t *testing.T) {
		database := strings.NewReader(`[
			{"Name": "John", "Wins": 19},
			{"Name": "David", "Wins": 36}]`)

		store := FileSystemPlayerStore{database}

		got := store.GetLeague()

		want := []Player{
			{"John", 19},
			{"David", 36},
		}

		assertLeague(t, got, want)

		// read again
		got = store.GetLeague()
		assertLeague(t, got, want)
	})

	t.Run("/get player score", func(t *testing.T) {
		database := strings.NewReader(`[
			{"Name": "John", "Wins": 19},
			{"Name": "David", "Wins": 36}]`)

		store := FileSystemPlayerStore{database}

		got := store.GetPlayerScore("John")
		want := 19
		assertScoreEquals(t, got, want)
	})
}

func assertScoreEquals(t *testing.T, got, want int) {
	t.Helper()

	if got != want {
		t.Errorf("got %d want %d", got, want)
	}
}
