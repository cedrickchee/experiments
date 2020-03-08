# Ultimate Go Programming Training

## Introduction

Ultimate Go by [Ardan labs](https://www.ardanlabs.com/ultimate-go/) is an **intermediate-level** class for developers with some experience with Go trying to **dig deeper** into the programming language. They want a more thorough understanding of the **language and its internals**. You will learn mechanics, semantics and make better engineering decisions.

This project contains the [training class material](https://github.com/ardanlabs/gotraining/tree/master/topics/courses/go) and my notes.

## Lessons

### Lesson 1: Design Guidelines

- Topics [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/README.md#design-guidelines)]
- Philosophy
- Prepare your mind [[summary](guidelines/README.md#prepare-your-mind)]
- Productivity vs performance [[summary](guidelines/README.md#productivity-versus-performance)]
- Correctness vs Performance [[summary](guidelines/README.md#correctness-versus-performance)]
- Code reviews [[summary](guidelines/README.md#code-reviews)]

### Language Mechanics

- Topics [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/courses/go/language/README.md)]

#### Lesson 2: Language Syntax

- Variables [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/variables/README.md) | [example code](language/variables/example1/example1.go) | [notes](language/variables/example1/README.md)]
  - Built-in types
  - Zero value concept
  - Declare and initialize variables
  - Conversion vs casting
- Struct Types [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/struct_types/README.md)]
- Pointers [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/pointers/README.md)]
  - Part 1 (Pass by Value)
  - Part 2 (Sharing Data)
  - Part 3 (Escape Analysis)
  - Part 4 (Stack Growth)
- Constants [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/constants/README.md)]
- Functions [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/functions/README.md)]

#### Lesson 3: Data Structures

- Data-Oriented Design
- Arrays [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/arrays/README.md)]
  - Part 1 (Mechanical Sympathy)
  - Part 2 (Semantics)
- Slices [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/slices/README.md)]
  - Part 1 (Declare and Length and Reference Types)
  - Part 2 (Appending Slices)
  - Part 3 (Taking Slices of Slices)
  - Part 4 (Slices and References)
  - Part 5 (Strings and Slices)
  - Part 6 (Range Mechanics)
  - Part 7 (Variadic Functions)
- Maps [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/maps/README.md)]
  - Declare, write, read, and delete
  - Absent keys
  - Map key restrictions
  - Map literals and range
  - Sorting maps by key
  - Taking an element's address
  - Maps are Reference Types

#### Lesson 4: Decoupling

- Methods [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/methods/README.md)]
  - Part 1 (Declare and Receiver Behavior)
  - Part 2 (Value and Pointer Semantics)
  - Part 3 (Function/Method Variables)
  - Part 4 (Named Typed Methods)
  - Part 5 (Function Types)
- Interfaces [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/interfaces/README.md)]
  - Part 1 (Polymorphism)
  - Part 2 (Method Sets and Address of Value)
  - Part 3 (Storage By Value)
  - Part 4 (Repetitive Code That Needs Polymorphism)
  - Part 5 (Type Assertions)
  - Part 6 (Conditional Type Assertions)
  - Part 7 (The Empty Interface and Type Switches)
- Embedding [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/embedding/README.md)]
  - Declaring Fields
  - Embedding types
  - Embedded types and interfaces
  - Outer and inner type interface implementations
- Exporting [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/exporting/README.md)]
  - Declare and access exported identifiers - Pkg
  - Declare and access exported identifiers - Main
  - Declare unexported identifiers and restrictions - Pkg
  - Declare unexported identifiers and restrictions - Main
  - Access values of unexported identifiers - Pkg
  - Access values of unexported identifiers - Main
  - Unexported struct type fields - Pkg
  - Unexported struct type fields - Main
  - Unexported embedded types - Pkg
  - Unexported embedded types - Main

### Software Design

- Topics [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/courses/go/design/README.md)]

#### Lesson 5: Composition

- Interface and Composition Design [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/design/composition/README.md)]
- Grouping Types
  - Grouping By State
  - Grouping By Behavior
- Decoupling
  - Struct Composition
  - Decoupling With Interface
  - Interface Composition
  - Decoupling With Interface Composition
  - Remove Interface Pollution
  - More Precise API
- Conversion and Assertions
  - Interface Conversions
  - Runtime Type Assertions
  - Behavior Changes
- Interface Pollution
  - Create Interface Pollution
  - Remove Interface Pollution
- Mocking
  - Package To Mock
  - Client
- Design Guidelines
