// Ginkgo BDD Testing Framework <http://onsi.github.io/ginkgo/>
// Gomega Matcher Library <http://onsi.github.io/gomega/>
package kata_test

import (
	"math"
	"math/rand"
	"strconv"
	"strings"

	. "."

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Example Test", func() {
	It("should test that the solution returns the correct value", func() {
		Expect(HighAndLow("8 3 -5 42 -1 0 0 -9 4 7 4 -4")).To(Equal("42 -9"))
	})
})

var _ = Describe("More Tests", func() {
	It("should test for varied input", func() {
		Expect(HighAndLow("4 5 29 54 4 0 -214 542 -64 1 -3 6 -6")).To(Equal("542 -214"))
	})
	It("should test for sorted input", func() {
		Expect(HighAndLow("10 2 -2 -10")).To(Equal("10 -10"))
	})
	It("should test for positive and negative input", func() {
		Expect(HighAndLow("1 -1")).To(Equal("1 -1"))
	})
	It("should test for positive and positive input", func() {
		Expect(HighAndLow("1 1")).To(Equal("1 1"))
	})
	It("should test for negative and negative input", func() {
		Expect(HighAndLow("-1 -1")).To(Equal("-1 -1"))
	})
	It("should test for positive, positive, and zero input", func() {
		Expect(HighAndLow("1 1 0")).To(Equal("1 0"))
	})
	It("should test for negative, negative, and zero input", func() {
		Expect(HighAndLow("-1 -1 0")).To(Equal("0 -1"))
	})
	It("should test for single input", func() {
		Expect(HighAndLow("42")).To(Equal("42 42"))
	})
})

var _ = Describe("Random Tests", func() {
	It("should test for randomly generated input", func() {
		rand.Seed(42)
		var nums []string
		for i := rand.Intn(42) + 1; i > 0; i-- {
			rint := rand.Intn(math.MaxInt32)
			if rand.Intn(2)&1 == 1 {
				rint *= -1
			}
			nums = append(nums, strconv.Itoa(rint))
		}
		low, _ := strconv.Atoi(nums[0])
		high := low
		for _, s := range nums {
			n, _ := strconv.Atoi(s)
			if n < low {
				low = n
			}
			if n > high {
				high = n
			}
		}
		Expect(HighAndLow(strings.Join(nums, " "))).To(Equal(strconv.Itoa(high) + " " + strconv.Itoa(low)))
	})
})
