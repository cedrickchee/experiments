package kata

import (
	"fmt"
	"regexp"
)

func PrinterError(s string) string {
	// a to m
	// example: "aaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbmmmmmmmmmmmmmmmmmmmxyz"
	ln := len(s)
	var badStrCnt int

	// matched, err := regexp.MatchString(`xyz.*`, s)
	// fmt.Println(matched, err)

	// re := regexp.MustCompile(`foo.?`)
	// fmt.Printf("%q\n", re.FindAll([]byte(`seafood fool`), -1))
	re := regexp.MustCompile(`[n-z]`)
	fmt.Printf("%s, badStr: %s\n", s, re.FindAllString(s, -1))
	badStrCnt = len(re.FindAllString(s, -1))

	res := fmt.Sprintf("%d/%d", badStrCnt, ln)
	return res
}
