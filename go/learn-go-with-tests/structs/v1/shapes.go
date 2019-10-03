package geometry

// Perimeter returns the perimeter of a rectangle
func Perimeter(width, height float64) float64 {
	return (width + height) * 2
}

// Area returns the area of a rectangle
func Area(width, height float64) float64 {
	return width * height
}
