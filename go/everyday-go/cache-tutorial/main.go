// The code in this package was based on the "Build a Go Cache in 10 Minutes"
// tutorial here: https://hackernoon.com/build-a-go-cache-in-10-minutes-c908a8255568

package main

import "fmt"

const SIZE = 5 // size of cache

// Note that the following doubly linked list data structures can
// be implemented idiomatically using container/list library in Go.

// Node pointers that is part of a Queue
type Node struct {
	Left  *Node
	Right *Node
	Val   string
}

// Queue is a doubly linked list of Node pointers
type Queue struct {
	Head   *Node
	Tail   *Node
	Length int
}

// Hash table maps string to Node in Queue
type Hash map[string]*Node

// Cache is implemented using hash table and doubly linked list
type Cache struct {
	Queue Queue
	Hash  Hash
}

// Create a new Queue instance
func NewQueue() Queue {
	head := &Node{}
	tail := &Node{}
	head.Right = tail
	tail.Left = head

	return Queue{Head: head, Tail: tail}
}

// Create a new Cache instance
func NewCache() Cache {
	return Cache{Queue: NewQueue(), Hash: Hash{}}
}

// Add node with new value or move node to front (hit) of Queue
func (c *Cache) Check(str string) {
	node := &Node{}
	if val, ok := c.Hash[str]; ok {
		node = c.Remove(val)
	} else {
		node = &Node{Val: str}
	}

	c.Add(node)
	c.Hash[str] = node
}

// Add node to front and evict node from back of Queue if Queue is full
func (c *Cache) Add(n *Node) {
	fmt.Printf("add: %s\n", n.Val)

	tmp := c.Queue.Head.Right
	c.Queue.Head.Right = n
	n.Left = c.Queue.Head
	n.Right = tmp
	tmp.Left = n

	c.Queue.Length++
	if c.Queue.Length > SIZE {
		c.Remove(c.Queue.Tail.Left)
	}
}

// Remove node from Queue
func (c *Cache) Remove(n *Node) *Node {
	fmt.Printf("remove: %s\n", n.Val)

	left := n.Left
	right := n.Right
	left.Right = right
	right.Left = left
	c.Queue.Length -= 1

	delete(c.Hash, n.Val)
	return n
}

func (c *Cache) Display() {
	c.Queue.Display()
}

func (q *Queue) Display() {
	node := q.Head.Right

	fmt.Printf("%d - [", q.Length)

	for i := 0; i < q.Length; i++ {
		fmt.Printf("{%s}", node.Val)
		if i < q.Length-1 {
			fmt.Printf(" <--> ")
		}
		node = node.Right
	}

	fmt.Println("]")
}

func main() {
	fmt.Println("START CACHE")

	cache := NewCache()

	data := []string{"cat", "blue", "dog", "tree", "dragon",
		"potato", "house", "tree", "cat"}

	for _, word := range data {
		cache.Check(word)
		cache.Display()
	}
}
