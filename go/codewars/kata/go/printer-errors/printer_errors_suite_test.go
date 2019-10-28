package kata_test

import (
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestPrinterErrors(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "PrinterErrors Suite")
}
