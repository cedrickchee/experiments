package romannumeral

import "strings"

// ConvertToRoman converts an Arabic number (numbers 0 to 9) to a Roman Numeral
func ConvertToRoman(arabic int) string {
	var result strings.Builder

	for arabic > 0 {
		switch {
		case arabic > 9:
			result.WriteString("X")
			arabic -= 10
		case arabic > 8:
			result.WriteString("IX")
			arabic -= 9
		case arabic > 4:
			result.WriteString("V")
			arabic -= 5
		case arabic > 3:
			result.WriteString("IV")
			arabic -= 4
		default:
			result.WriteString("I")
			arabic--
		}
	}

	return result.String()
}
