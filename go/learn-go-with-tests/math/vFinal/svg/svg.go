// Package svg produces an SVG clockface representation of a time.
package svg

import (
	"fmt"
	"io"
	"time"

	cf "github.com/cedrickchee/learn-go-with-tests/math/vFinal/clockface"
)

const (
	secondHandLength = 90
	minuteHandLength = 80
	hourHandLength   = 50
	clockCentreX     = 150
	clockCentreY     = 150
)

// Write writes an SVG representation of an analogue clock, showing the time t, to the writer w
func Write(w io.Writer, t time.Time) {
	io.WriteString(w, svgStart)
	io.WriteString(w, bezel)
	secondHand(w, t)
	minuteHand(w, t)
	hourHand(w, t)
	io.WriteString(w, svgEnd)
}

const svgStart = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg"
     width="100%"
     height="100%"
     viewBox="0 0 300 300"
     version="2.0">`

const bezel = `<circle cx="150" cy="150" r="100" style="fill:#fff;stroke:#000;stroke-width:5px;"/>`

const svgEnd = `</svg>`

func secondHand(w io.Writer, t time.Time) {
	p := makeHand(cf.SecondHandPoint(t), secondHandLength)

	fmt.Fprintf(w, `<line x1="150" y1="150" x2="%.3f" y2="%.3f" style="fill:none;stroke:#f00;stroke-width:3px;"/>`, p.X, p.Y)
}

func minuteHand(w io.Writer, t time.Time) {
	p := makeHand(cf.MinuteHandPoint(t), minuteHandLength)

	fmt.Fprintf(w, `<line x1="150" y1="150" x2="%.3f" y2="%.3f" style="fill:none;stroke:#000;stroke-width:3px;"/>`, p.X, p.Y)
}

func hourHand(w io.Writer, t time.Time) {
	p := makeHand(cf.HourHandPoint(t), hourHandLength)

	fmt.Fprintf(w, `<line x1="150" y1="150" x2="%.3f" y2="%.3f" style="fill:none;stroke:#000;stroke-width:3px;"/>`, p.X, p.Y)
}

// makeHand makes the unit vector of the second or minute hand of an analogue clock at time `t`
// represented as a Point.
func makeHand(p cf.Point, length float64) cf.Point {
	// do three things to convert our unit vector into a point on the SVG
	// 1. Scale it to the length of the hand
	// 2. Flip it over the X axis because to account for the SVG having an origin in the top left hand corner
	// 3. Translate it to the right position (so that it's coming from an origin of (150,150))
	p = cf.Point{X: p.X * length, Y: p.Y * length}             // scale
	p = cf.Point{X: p.X, Y: -p.Y}                              // flip
	p = cf.Point{X: p.X + clockCentreX, Y: p.Y + clockCentreY} // translate
	return p
}
