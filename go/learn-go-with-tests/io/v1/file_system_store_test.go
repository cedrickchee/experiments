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
	})
}
