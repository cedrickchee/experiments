package reflection

import "reflect"

func walk(x interface{}, fn func(input string)) {
	val := getValue(x)

	numberOfValues := 0
	var getField func(int) reflect.Value

	switch val.Kind() {
	case reflect.Struct:
		numberOfValues = val.NumField()
		getField = val.Field
	case reflect.Slice:
		numberOfValues = val.Len()
		getField = val.Index
	case reflect.String:
		fn(val.String())
	}

	for i := 0; i < numberOfValues; i++ {
		walk(getField(i).Interface(), fn)
	}

	// if val.Kind() == reflect.Slice {
	// 	for i := 0; i < val.Len(); i++ {
	// 		walk(val.Index(i).Interface(), fn)
	// 	}
	// 	return
	// }

	// for i := 0; i < val.NumField(); i++ {
	// 	field := val.Field(i)

	// 	switch field.Kind() {
	// 	case reflect.String:
	// 		fn(field.String())
	// 	case reflect.Struct:
	// 		walk(field.Interface(), fn)
	// 	}
	// }
}

func getValue(x interface{}) reflect.Value {
	val := reflect.ValueOf(x)

	if val.Kind() == reflect.Ptr {
		val = val.Elem()
	}

	return val
}
