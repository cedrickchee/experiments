package main

// InMemoryPlayerStore collects data about players in memory
type InMemoryPlayerStore struct {
	score map[string]int
}

// GetPlayerScore retrieves scores for a given player
func (i *InMemoryPlayerStore) GetPlayerScore(name string) int {
	return i.score[name]
}

// RecordWin will record a player's win
func (i *InMemoryPlayerStore) RecordWin(name string) {
	i.score[name]++
}

// NewInMemoryPlayerStore initialises an empty player store
func NewInMemoryPlayerStore() *InMemoryPlayerStore {
	return &InMemoryPlayerStore{map[string]int{}}
}
