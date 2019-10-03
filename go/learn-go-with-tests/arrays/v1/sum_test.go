package datamath

import "testing"

func TestSum(t *testing.T) {
	var numbers = [5]int{1, 2, 3, 4, 5}

	got := Sum(numbers)
	expected := 15

	if got != expected {
		t.Errorf("got %d expected %d given %v", got, expected, numbers)
	}
}
