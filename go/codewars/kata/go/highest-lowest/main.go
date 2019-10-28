package kata

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
)

func HighAndLow(in string) string {
	// Code here or
	strs := strings.Split(in, " ")
	arr := make([]int, len(strs))
	for i := range arr {
		arr[i], _ = strconv.Atoi(strs[i])
	}
	min, max := MinMax(arr)
	str := fmt.Sprintf("%d %d", max, min)

	return str
}

// MinMax an array of numbers
func MinMax(v []int) (int, int) {
	sort.Ints(v)
	return v[0], v[len(v)-1]
}
