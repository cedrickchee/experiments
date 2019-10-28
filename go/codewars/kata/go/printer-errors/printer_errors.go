package kata

import (
	"fmt"
)

func PrinterError(s string) string {
	// re := regexp.MustCompile(`[n-z]`)

	// return fmt.Sprintf("%d/%d", len(re.FindAllString(s, -1)), len(s))

	// Other solution
	errors := 0
	for _, c := range s {
		if c >= 'a' && c <= 'm' {
			continue
		} else {
			errors++
		}
	}

	return fmt.Sprintf("%d/%d", errors, len(s))
}
