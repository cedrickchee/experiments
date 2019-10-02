package main

import "testing"

func TestHello(t *testing.T) {
	got := Hello("John")
	want := "Hello, John"

	if got != want {
		t.Errorf("got %q want %q", got, want)
	}
}
