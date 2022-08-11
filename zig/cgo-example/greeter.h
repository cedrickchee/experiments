struct Greetee {
    const char *name;
    int year;
};

#ifndef _GREETER_H
#define _GREETER_H

// Takes a string for the name, an integer for the year, and a pointer to write
// the resulting greeting to. It returns an integer which specifies how many
// characters were written, and assumes the required buffer space in out has
// already been allocated.
// int greet(const char *name, int year, char *out);

int greet(struct Greetee *g, char *out);

#endif