package clockface

import (
	"math"
	"time"
)

// A Point represents a two dimensional Cartesian coordinate
type Point struct {
	X float64
	Y float64
}

const secondHandLength = 90
const clockCentreX = 150
const clockCentreY = 150

// SecondHand is the unit vector of the second hand of an analogue clock at time `t`
// represented as a Point.
func SecondHand(t time.Time) Point {
	// do three things to convert our unit vector into a point on the SVG
	// 1. Scale it to the length of the hand
	// 2. Flip it over the X axis because to account for the SVG having an origin in the top left hand corner
	// 3. Translate it to the right position (so that it's coming from an origin of (150,150))
	p := secondHandPoint(t)
	p = Point{p.X * secondHandLength, p.Y * secondHandLength} // scale
	p = Point{p.X, -p.Y}                                      // flip
	p = Point{p.X + clockCentreX, p.Y + clockCentreY}         // translate

	return p
}

func secondsInRadians(t time.Time) float64 {
	return float64(t.Second()) / 30 * math.Pi // or (math.Pi / (30 / (float64(t.Second()))))
}

func secondHandPoint(t time.Time) Point {
	// measure the angle from 12 o'clock rather than from the X axis (3 o'clock),
	// we need to swap the axis around; now x = sin(a) and y = cos(a).
	angle := secondsInRadians(t)
	x := math.Sin(angle)
	y := math.Cos(angle)

	return Point{x, y}
}
