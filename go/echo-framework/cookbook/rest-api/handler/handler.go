package handler

import (
	"gopkg.in/mgo.v2"
)

type Handler struct {
	DB *mgo.Session
}

// Key (should come from somewhere else).
const Key = "secret"
