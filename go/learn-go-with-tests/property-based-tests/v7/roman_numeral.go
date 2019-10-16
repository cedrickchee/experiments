package romannumeral

import "strings"

// RomanNumeral represents Arabic number and its Roman Numeral symbol
type RomanNumeral struct {
	Value  int
	Symbol string
}

var romanNumerals = []RomanNumeral{
	{10, "X"},
	{9, "IX"},
	{5, "V"},
	{4, "IV"},
	{1, "I"},
}

// ConvertToRoman converts an Arabic number (numbers 0 to 9) to a Roman Numeral
func ConvertToRoman(arabic int) string {
	var result strings.Builder

	for _, numeral := range romanNumerals {
		for arabic >= numeral.Value {
			result.WriteString(numeral.Symbol)
			arabic -= numeral.Value
		}
	}

	return result.String()
}
