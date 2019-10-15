package reflection

import (
	"reflect"
	"testing"
)

func TestWalk(t *testing.T) {
	cases := []struct {
		Name          string
		Input         interface{}
		ExpectedCalls []string
	}{
		{
			"Struct with one string field",
			struct {
				Name string
			}{"John"},
			[]string{"John"},
		},
		{
			"Struct with two string fields",
			struct {
				Name string
				City string
			}{"John", "Singapore"},
			[]string{"John", "Singapore"},
		},
		{
			"Struct with non string field",
			struct {
				Name string
				Age  int
			}{"John", 30},
			[]string{"John"},
		},
		{
			"Nested fields",
			Person{
				"John",
				Profile{30, "Singapore"},
			},
			[]string{"John", "Singapore"},
		},
		{
			"Pointers to things",
			&Person{
				"John",
				Profile{30, "Singapore"},
			},
			[]string{"John", "Singapore"},
		},
		{
			"Slices",
			[]Profile{
				{30, "Singapore"},
				{32, "Bali"},
			},
			[]string{"Singapore", "Bali"},
		},
		{
			"Arrays",
			[2]Profile{
				{30, "Singapore"},
				{32, "Bali"},
			},
			[]string{"Singapore", "Bali"},
		},
	}

	for _, test := range cases {
		t.Run(test.Name, func(t *testing.T) {
			var got []string

			walk(test.Input, func(input string) {
				got = append(got, input)
			})

			if !reflect.DeepEqual(got, test.ExpectedCalls) {
				t.Errorf("got %v, want %v", got, test.ExpectedCalls)
			}
		})
	}

	t.Run("with maps", func(t *testing.T) {
		aMap := map[string]string{
			"Foo": "Bar",
			"Baz": "Qux",
		}

		var got []string

		walk(aMap, func(input string) {
			got = append(got, input)
		})

		assertContains(t, got, "Bar")
		assertContains(t, got, "Qux")
	})
}

type Person struct {
	Name    string
	Profile Profile
}

type Profile struct {
	Age  int
	City string
}

func assertContains(t *testing.T, haystack []string, needle string) {
	contains := false

	for _, x := range haystack {
		if x == needle {
			contains = true
		}
	}

	if !contains {
		t.Errorf("expected %+v to contain %q but it didn't", haystack, needle)
	}
}
