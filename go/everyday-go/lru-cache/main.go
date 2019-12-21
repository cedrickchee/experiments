// LeetCode solution for Least Recently Used (LRU) cache algorithm:
// https://leetcode.com/problems/lru-cache/
//

package main

import (
	"container/list"
	"fmt"
)

// LRUCache contains a map and a doubly linked list
type LRUCache struct {
	queue *list.List            // doubly linked list
	hash  map[int]*list.Element // hash table for checking if list node exists
	size  int                   // queue size
}

// Pair is the value of a list node
type Pair struct {
	key   int
	value string
}

// NewLRUCache is a constructor that initializes a new LRUCache.
func NewLRUCache(size int) LRUCache {
	return LRUCache{
		size:  size,
		queue: new(list.List),
		hash:  make(map[int]*list.Element, size),
	}
}

// Get a list node from the hash map
func (c *LRUCache) Get(key int) string {
	// Check if list node exists
	if node, ok := c.hash[key]; ok {
		val := node.Value.(*list.Element).Value.(Pair).value

		// It's a cache hit. So, move node to front
		c.queue.MoveToFront(node)

		return val
	}

	// List node is not found
	return ""
}

// Put key and value in the LRUCache
func (c *LRUCache) Put(key int, value string) {
	// Check if list node exists
	if node, ok := c.hash[key]; ok {
		// Move the node to front
		c.queue.MoveToFront(node)
		// Update the value of a list node
		node.Value.(*list.Element).Value = Pair{key: key, value: value}
	} else {
		// Delete the last list node if the list is full
		if c.queue.Len() == c.size {
			// Get the last node of list
			last := c.queue.Back()
			// Get the key that we want to delete
			idx := last.Value.(*list.Element).Value.(Pair).key
			// Delete the node pointer in the hash map by key
			delete(c.hash, idx)
			// Remove the last list node
			c.queue.Remove(last)
		}

		// Initialize a list node
		node := &list.Element{
			Value: Pair{
				key:   key,
				value: value,
			},
		}

		// Push the new list node into the list
		ptr := c.queue.PushFront(node)

		// Save the node pointer in the hash map
		c.hash[key] = ptr
	}
}

func main() {
	obj := NewLRUCache(2) // nil

	fmt.Println("Put(1, \"cat\")")
	obj.Put(1, "cat")                  // nil, queue: [1:cat]
	fmt.Println("Get(1):", obj.Get(1)) // cat, queue: [1:cat]
	fmt.Println("Queue obj:", obj.queue)
	fmt.Println("front/head:", obj.queue.Front().Value.(*list.Element).Value)
	fmt.Println("back/tail:", obj.queue.Back().Value.(*list.Element).Value)
	fmt.Println("")

	fmt.Println("Put(2, \"dog\")")
	obj.Put(2, "dog")                  // nil, queue: [2:dog<-->1:cat]
	fmt.Println("Get(1):", obj.Get(1)) // cat, queue: [1:cat<-->2:dog]
	fmt.Println("Get(2):", obj.Get(2)) // dog, queue: [2:dog<-->1:cat]
	fmt.Println("front/head:", obj.queue.Front().Value.(*list.Element).Value)
	fmt.Println("back/tail:", obj.queue.Back().Value.(*list.Element).Value)
	fmt.Println("")

	fmt.Println("Put(3, \"bear\")")
	obj.Put(3, "bear")                 // nil, queue: [3:bear<-->2:dog]
	fmt.Println("Get(1):", obj.Get(1)) // "", queue: [3:bear<-->2:dog]
	fmt.Println("Get(2):", obj.Get(2)) // dog, queue: [2:dog<-->3:bear]
	fmt.Println("Get(3):", obj.Get(3)) // bear, queue: [3:bear<-->2:dog]
	fmt.Println("front/head:", obj.queue.Front().Value.(*list.Element).Value)
	fmt.Println("back/tail:", obj.queue.Back().Value.(*list.Element).Value)
	fmt.Println("")

	fmt.Println("Put(4, \"monkey\")")
	obj.Put(4, "monkey")               // nil, queue: [4:monkey<-->3:bear]
	fmt.Println("Get(1):", obj.Get(1)) // "", queue: [4:monkey<-->3:bear]
	fmt.Println("Get(2):", obj.Get(2)) // "", queue: [4:monkey<-->3:bear]
	fmt.Println("Get(3):", obj.Get(3)) // bear, linked list: [3:bear<-->4:monkey]
	fmt.Println("Get(4):", obj.Get(4)) // monkey, linked list: [4:monkey<-->3:bear]
	fmt.Println("front/head:", obj.queue.Front().Value.(*list.Element).Value)
	fmt.Println("back/tail:", obj.queue.Back().Value.(*list.Element).Value)
}
