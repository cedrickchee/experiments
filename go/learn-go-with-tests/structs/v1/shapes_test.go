package geometry

import "testing"

func TestPerimeter(t *testing.T) {
	got := Perimeter(50.0, 50.0)
	want := 200.0

	if got != want {
		t.Errorf("got %.2f want %.2f", got, want)
	}
}

func TestArea(t *testing.T) {
	got := Area(10.0, 5.0)
	want := 50.0

	if got != want {
		t.Errorf("got %.2f want %.2f", got, want)
	}
}
