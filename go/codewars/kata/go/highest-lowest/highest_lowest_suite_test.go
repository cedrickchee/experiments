package kata_test

import (
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestHighestLowest(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "HighestLowest Suite")
}
