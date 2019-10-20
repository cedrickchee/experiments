package main

import (
	"io"
	"io/ioutil"
	"os"
	"testing"
)

func TestFileSystemStore(t *testing.T) {
	t.Run("/league from a render", func(t *testing.T) {
		database, cleanDatabase := createTempFile(t, `[
			{"Name": "John", "Wins": 19},
			{"Name": "David", "Wins": 36}]`)
		defer cleanDatabase()

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
		database, cleanDatabase := createTempFile(t, `[
			{"Name": "John", "Wins": 19},
			{"Name": "David", "Wins": 36}]`)
		defer cleanDatabase()

		store := FileSystemPlayerStore{database}

		got := store.GetPlayerScore("John")
		want := 19
		assertScoreEquals(t, got, want)
	})

	t.Run("store wins for existing players", func(t *testing.T) {
		database, cleanDatabase := createTempFile(t, `[
			{"Name": "John", "Wins": 19},
			{"Name": "David", "Wins": 36}]`)
		defer cleanDatabase()

		store := FileSystemPlayerStore{database}

		store.RecordWin("John")

		got := store.GetPlayerScore("John")
		want := 20

		assertScoreEquals(t, got, want)
	})

	t.Run("store wins for new players", func(t *testing.T) {
		database, cleanDatabase := createTempFile(t, `[
			{"Name": "John", "Wins": 19},
			{"Name": "David", "Wins": 36}]`)
		defer cleanDatabase()

		store := FileSystemPlayerStore{database}

		store.RecordWin("Oliver")

		got := store.GetPlayerScore("Oliver")
		want := 1

		assertScoreEquals(t, got, want)
	})
}

func assertScoreEquals(t *testing.T, got, want int) {
	t.Helper()

	if got != want {
		t.Errorf("got %d want %d", got, want)
	}
}

func createTempFile(t *testing.T, initialData string) (io.ReadWriteSeeker, func()) {
	t.Helper()

	tmpFile, err := ioutil.TempFile("", "db")

	if err != nil {
		t.Fatalf("could not create a temp file %v", err)
	}

	tmpFile.Write([]byte(initialData))

	removeFile := func() {
		tmpFile.Close()
		os.Remove(tmpFile.Name())
	}

	return tmpFile, removeFile
}
