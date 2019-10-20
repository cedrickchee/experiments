package main

import "sync"

// InMemoryPlayerStore collects data about players in memory
type InMemoryPlayerStore struct {
	score map[string]int
	// A mutex is used to synchronize read/write access to the map
	lock sync.RWMutex
}

// GetPlayerScore retrieves scores for a given player
func (i *InMemoryPlayerStore) GetPlayerScore(name string) int {
	i.lock.Lock()
	defer i.lock.Unlock()
	return i.score[name]
}

// RecordWin will record a player's win
func (i *InMemoryPlayerStore) RecordWin(name string) {
	i.lock.RLock()
	defer i.lock.RUnlock()
	i.score[name]++
}

// GetLeague returns a collection of Players
func (i *InMemoryPlayerStore) GetLeague() []Player {
	var league []Player
	for name, wins := range i.score {
		league = append(league, Player{name, wins})
	}
	return league
}

// NewInMemoryPlayerStore initialises an empty player store
func NewInMemoryPlayerStore() *InMemoryPlayerStore {
	return &InMemoryPlayerStore{
		map[string]int{},
		sync.RWMutex{},
	}
}
