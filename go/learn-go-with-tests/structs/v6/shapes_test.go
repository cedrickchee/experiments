package geometry

import "testing"

func TestPerimeter(t *testing.T) {
	rectangle := Rectangle{50.0, 50.0}
	got := Perimeter(rectangle)
	want := 200.0

	if got != want {
		t.Errorf("got %.2f want %.2f", got, want)
	}
}

func TestArea(t *testing.T) {
	areaTests := []struct {
		shape Shape
		want  float64
	}{
		{Rectangle{10.0, 5.0}, 50.0},
		{Circle{10}, 314.1592653589793},
		{Triangle{12, 6}, 36.0},
	}

	for _, tt := range areaTests {
		got := tt.shape.Area()

		if got != tt.want {
			t.Errorf("got %g want %g", got, tt.want)
		}
	}
}
