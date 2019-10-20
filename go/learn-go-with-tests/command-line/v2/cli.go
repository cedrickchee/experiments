package poker

// CLI helps players through a game of poker
type CLI struct {
	store PlayerStore
}

// PlayPoker starts the game
func (c *CLI) PlayPoker() {
	c.store.RecordWin("John")
}
