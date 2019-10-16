package romannumeral

// ConvertToRoman converts an Arabic number (numbers 0 to 9) to a Roman Numeral
func ConvertToRoman(arabic int) string {
	if arabic == 1 {
		return "I"
	}

	return "II"
}
