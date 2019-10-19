package main

import (
	"io"
)

// FileSystemPlayerStore stores players in the filesystem
type FileSystemPlayerStore struct {
	database io.Reader
}

// GetLeague returns the scores of all the players
func (f *FileSystemPlayerStore) GetLeague() []Player {
	league, _ := NewLeague(f.database)
	return league
}
