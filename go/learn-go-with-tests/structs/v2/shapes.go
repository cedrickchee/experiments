package geometry

// Rectangle has the dimensions of a rectangle
type Rectangle struct {
	Width  float64
	Height float64
}

// Perimeter returns the perimeter of a rectangle
func Perimeter(rectangle Rectangle) float64 {
	return (rectangle.Width + rectangle.Height) * 2
}

// Area returns the area of a rectangle
func Area(rectangle Rectangle) float64 {
	return rectangle.Width * rectangle.Height
}
