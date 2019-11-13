package problem0420

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
)

// tcs is testcase slice
var tcs = []struct {
	s   string
	ans int
}{
	{"", 6},
	{"aB3aB3", 0},
	{"aaaaaaaaaaaaaaaaaaaaa", 7},
	{"aaaaaaaaaaaaaaaaaaaaaa", 8},
	{"aaaAaaaAaaaAaaaAaaaAa", 5},
	{"aadssfasfASDaaaaaaaaaaASDfA235234ADFadfASDFa234324", 30},
}

func Test_strongPasswordChecker(t *testing.T) {
	ast := assert.New(t)

	for _, tc := range tcs {
		fmt.Printf("case: %v\n", tc)
		ast.Equal(tc.ans, strongPasswordChecker(tc.s), "input:%v", tc)
	}
}

func Benchmark_strongPasswordChecker(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for _, tc := range tcs {
			strongPasswordChecker(tc.s)
		}
	}
}
