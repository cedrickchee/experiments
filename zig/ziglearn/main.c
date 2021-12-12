// ************************************************************************
// Working with C
// ************************************************************************

//
// Translate-C
//

#include <stddef.h>

void int_sort(int* array, size_t count) {
    for (int i = 0; i < count - 1; i++) {
        for (int j = 0; j < count - i - 1; j++) {
            if (array[j] > array[j+1]) {
                int temp = array[j];
                array[j] = array[j+1];
                array[j+1] = temp;
            }
        }
    }
}
