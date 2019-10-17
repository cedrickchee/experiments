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

func secondsInRadians(t time.Time) float64 {
	return float64(t.Second()) / 30 * math.Pi // or (math.Pi / (30 / (float64(t.Second()))))
}

func secondHandPoint(t time.Time) Point {
	// measure the angle from 12 o'clock rather than from the X axis (3 o'clock),
	// we need to swap the axis around; now x = sin(a) and y = cos(a).
	return angleToPoint(secondsInRadians(t))
}

func minutesInRadians(t time.Time) float64 {
	return (secondsInRadians(t) / 60) +
		(float64(t.Minute()) / 30 * math.Pi)
}

func minuteHandPoint(t time.Time) Point {
	return angleToPoint(minutesInRadians(t))
}

func hoursInRadians(t time.Time) float64 {
	return (minutesInRadians(t) / 12) + (math.Pi / (6 / (float64(t.Hour() % 12))))
}

func hourHandPoint(t time.Time) Point {
	return angleToPoint(hoursInRadians(t))
}

func angleToPoint(angle float64) Point {
	x := math.Sin(angle)
	y := math.Cos(angle)

	return Point{x, y}
}
