package main

import (
	"fmt"
	"net/http"
)

// PlayerServer ...
func PlayerServer(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "20")
}
