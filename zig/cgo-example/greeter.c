#include "greeter.h"
#include <stdio.h>

// int greet(const char *name, int year, char *out) {
//     int n;

//     // write the greeting message to the buffer of characters pointed to by out.
//     // Note that we don’t check for buffer overflow here, for the sake of
//     // simplicity.
//     n = sprintf(out, "Greetings, %s from %d! We come in peace :)", name, year);

//     return n;
// }

int greet(struct Greetee *g, char *out) {
    int n;

    // write the greeting message to the buffer of characters pointed to by out.
    // Note that we don’t check for buffer overflow here, for the sake of
    // simplicity.
    n = sprintf(out, "Greetings, %s from %d! We come in peace :)", g->name, g->year);

    return n;
}