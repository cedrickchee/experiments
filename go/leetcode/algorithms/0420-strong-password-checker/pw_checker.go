// Solution for LeetCode problem 0420
// https://leetcode.com/problems/strong-password-checker/

package problem0420

func strongPasswordChecker(s string) int {
	// Check conditions: It must contain at least one lowercase letter, at
	// least one uppercase letter, and at least one digit.
	lcaseCnt, ucaseCnt, digitCnt, missingCnt := 1, 1, 1, 3
	for i := range s {
		if 0 < lcaseCnt && 'a' <= s[i] && s[i] <= 'z' {
			lcaseCnt--
			missingCnt--
		}
		if 0 < ucaseCnt && 'A' <= s[i] && s[i] <= 'Z' {
			ucaseCnt--
			missingCnt--
		}
		if 0 < digitCnt && '0' <= s[i] && s[i] <= '9' {
			digitCnt--
			missingCnt--
		}

		if missingCnt == 0 {
			break
		}
	}

	// Check conditions: It must NOT contain three repeating characters in a row
	var replace, ones, twos int

	for z := 0; z+2 < len(s); z++ {
		if s[z] != s[z+1] || s[z+1] != s[z+2] {
			continue
		}

		repeatingCharCnt := 2
		for z+2 < len(s) && s[z] == s[z+2] {
			repeatingCharCnt++
			z++
		}

		replace += repeatingCharCnt / 3
		if repeatingCharCnt%3 == 0 {
			ones++
		} else if repeatingCharCnt%3 == 1 {
			twos++
		}
	}

	// Check conditions: It has at least 6 characters and at most 20 characters.
	if len(s) < 6 {
		return max(missingCnt, 6-len(s))
	}

	if len(s) <= 20 {
		return max(missingCnt, replace)
	}

	// Insertion, deletion or replace of any one character are all considered as one change.
	delete := len(s) - 20

	replace -= min(delete, ones)
	replace -= min(max(delete-ones, 0), twos*2) / 2
	replace -= max(delete-ones-2*twos, 0) / 3

	return delete + max(missingCnt, replace)
}

// Utility functions
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
