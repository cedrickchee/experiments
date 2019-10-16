package romannumeral

import "strings"

// RomanNumeral represents Arabic number and its Roman Numeral symbol
type RomanNumeral struct {
	Value  uint16
	Symbol string
}

type romanNumerals []RomanNumeral

// ValueOf takes some bytes of symbols
func (r romanNumerals) ValueOf(symbols ...byte) uint16 {
	symbol := string(symbols)

	for _, s := range r {
		if s.Symbol == symbol {
			return s.Value
		}
	}
	return 0
}

func (r romanNumerals) Exists(symbols ...byte) bool {
	symbol := string(symbols)

	for _, s := range r {
		if s.Symbol == symbol {
			return true
		}
	}
	return false
}

var allRomanNumerals = romanNumerals{
	{1000, "M"},
	{900, "CM"},
	{500, "D"},
	{400, "CD"},
	{100, "C"},
	{90, "XC"},
	{50, "L"},
	{40, "XL"},
	{10, "X"},
	{9, "IX"},
	{5, "V"},
	{4, "IV"},
	{1, "I"},
}

// Extracting the numerals, offering a Symbols method to retrieve them as a slice
type windowedRoman string

func (w windowedRoman) Symbols() (symbols [][]byte) {
	// Example of w value "IV"
	for i := 0; i < len(w); i++ {
		symbol := w[i] // When you index strings in Go, you get a byte
		notAtEnd := i+1 < len(w)

		if notAtEnd && isSubtractive(symbol) && allRomanNumerals.Exists(symbol, w[i+1]) {
			symbols = append(symbols, []byte{byte(symbol), byte(w[i+1])})
			i++
		} else {
			symbols = append(symbols, []byte{byte(symbol)})
		}
	}
	return
}

// ConvertToRoman converts an Arabic number (numbers 0 to 9) to a Roman Numeral
func ConvertToRoman(arabic uint16) string {
	var result strings.Builder

	for _, numeral := range allRomanNumerals {
		for arabic >= numeral.Value {
			result.WriteString(numeral.Symbol)
			arabic -= numeral.Value
		}
	}

	return result.String()
}

// ConvertToArabic converts a Roman Numeral to an Arabic number
func ConvertToArabic(roman string) (total uint16) {
	// Iterate over the symbols and total them
	for _, symbols := range windowedRoman(roman).Symbols() {
		total += allRomanNumerals.ValueOf(symbols...)
	}
	return
}

// Figure out if the symbol we are currently dealing with is a two character subtractive symbol
func isSubtractive(symbol uint8) bool {
	// symbol:
	// byte is an alias for uint8 and is equivalent to uint8 in all ways.
	// It is used, by convention, to distinguish byte values from 8-bit unsigned integer values.
	return symbol == 'I' || symbol == 'X' || symbol == 'C'
}
