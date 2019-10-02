package main

import "testing"

func TestHello(t *testing.T) {
	assertCorrectMessage := func(t *testing.T, got, want string) {
		t.Helper()
		if got != want {
			t.Errorf("got %q want %q", got, want)
		}
	}

	t.Run("saying hello to people", func(t *testing.T) {
		got := Hello("John", "")
		want := "Hello, John"
		assertCorrectMessage(t, got, want)
	})

	t.Run("say 'Hello, World' when an empty string is supplied", func(t *testing.T) {
		got := Hello("", "")
		want := "Hello, World"
		assertCorrectMessage(t, got, want)
	})

	t.Run("say hello in Spanish", func(t *testing.T) {
		got := Hello("Fernando", "Spanish")
		want := "Hola, Fernando"
		assertCorrectMessage(t, got, want)
	})

	t.Run("say hello in French", func(t *testing.T) {
		got := Hello("Francois", "French")
		want := "Bonjour, Francois"
		assertCorrectMessage(t, got, want)
	})
}
