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

- Variables [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/variables/README.md) | [example code](language/variables/example1/example1.go) | [notes](language/variables/example1/README.md) | [exercise 1 solution](language/variables/exercise1/exercise1.go)]
  - Built-in types
  - Zero value concept
  - Declare and initialize variables
  - Conversion vs casting
- Struct Types [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/struct_types/README.md) | [notes](language/struct_types/README.md) | [exercise 1 solution](language/struct_types/exercise1/exercise1.go)]
  - Declare, create and initialize struct types [[example code](language/struct_types/example1/example1.go)]
  - Anonymous struct types [[example code](language/struct_types/example2/example2.go)]
  - Named vs Unnamed types [[example code](language/struct_types/example3/example3.go)]
- Pointers [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/pointers/README.md) | [notes](language/pointers/README.md) | [exercise 1 solution](language/pointers/exercise1/exercise1.go) | [exercise 2 solution](language/pointers/exercise2/exercise2.go)]
  - Part 1 (Pass by Value) [[example code](language/pointers/example1/example1.go)]
  - Part 2 (Sharing Data) [[example code](language/pointers/example2/example2.go) | [example code](language/pointers/example3/example3.go)]
  - Part 3 (Escape Analysis) [[example code](language/pointers/example4/example4.go)]
  - Part 4 (Stack Growth) [[example code](language/pointers/example5/example5.go)]
  - Part 5 (Garbage Collection)
- Constants [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/constants/README.md) | [notes](language/constants/README.md) | [exercise 1 solution](language/constants/exercise1/exercise1.go)]
  - Declare and initialize constants [[example code](language/constants/example1/example1.go)]
  - Parallel type system (Kind) [[example code](language/constants/example2/example2.go)]
  - iota  [[example code](language/constants/example3/example3.go)]
  - Implicit conversion [[example code](language/constants/example4/example4.go)]
- Functions [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/functions/README.md) | [notes](language/functions/README.md) | [exercise 1 solution](language/functions/exercise1/exercise1.go)]
  - Return multiple values [[example code](language/functions/example1/example1.go)]
  - Blank identifier [[example code](language/functions/example2/example2.go)]
  - Redeclarations [[example code](language/functions/example3/example3.go)]
  - Anonymous Functions/Closures [[example code](language/functions/example4/example4.go)]
  - Advanced code review
    - Recover panics [[example code](language/functions/advanced/example1/example1.go)]

#### Lesson 3: Data Structures

- Data-Oriented Design
  - [Design guidelines](https://github.com/ardanlabs/gotraining/blob/master/topics/go/#data-oriented-design) for data oriented design.
  - [[Notes](language/arrays/data_oriented_design.md)]
- Arrays [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/arrays/README.md) | [notes](language/arrays/README.md) | [exercise 1 solution](language/arrays/exercise1/exercise1.go)]
  - Part 1 (Mechanical Sympathy)
  - Part 2 (Semantics)
    - Declare, initialize and iterate [[example code](language/arrays/example1/example1.go)]
    - Different type arrays [[example code](language/arrays/example2/example2.go)]
    - Contiguous memory allocations [[example code](language/arrays/example3/example3.go)]
    - Range mechanics [[example code](language/arrays/example4/example4.go)]
- Slices [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/slices/README.md) | [notes](language/slices/README.md) | [exercise 1 solution](language/slices/exercise1/exercise1.go)]
  - Part 1
    - Declare and Length [[example code](language/slices/example1/example1.go)]
    - Reference Types [[example code](language/slices/example2/example2.go)]
  - Part 2 (Appending Slices) [[example code](language/slices/example4/example4.go)]
  - Part 3 (Taking Slices of Slices) [[example code](language/slices/example3/example3.go)]
  - Part 4 (Slices and References) [[example code](language/slices/example5/example5.go)]
  - Part 5 (Strings and Slices) [[example code](language/slices/example6/example6.go)]
  - Part 6 (Range Mechanics) [[example code](language/slices/example8/example8.go)]
  - Part 7 (Variadic Functions) [[example code](language/slices/example7/example7.go)]
- Maps [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/maps/README.md) | [notes](language/maps/README.md) | [exercise 1 solution](language/maps/exercise1/exercise1.go)]
  - Declare, write, read, and delete [[example code](language/maps/example1/example1.go)]
  - Absent keys [[example code](language/maps/example2/example2.go)]
  - Map key restrictions [[example code](language/maps/example3/example3.go)]
  - Map literals and range [[example code](language/maps/example4/example4.go)]
  - Sorting maps by key [[example code](language/maps/example5/example5.go)]
  - Taking an element's address [[example code](language/maps/example6/example6.go)]
  - Maps are Reference Types [[example code](language/maps/example7/example7.go)]

#### Lesson 4: Decoupling

- Methods [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/methods/README.md) | [notes](language/methods/README.md) | [exercise 1 solution](language/methods/exercise1/exercise1.go)]
  - Part 1 (Declare and Receiver Behavior) [[example code](language/methods/example1/example1.go)]
  - Part 2 (Value and Pointer Semantics) [[example code](language/methods/example5/example5.go)]
  - Part 3 (Function/Method Variables) [[example code](language/methods/example3/example3.go)]
  - Part 4 (Named Typed Methods) [[example code](language/methods/example2/example2.go)]
  - Part 5 (Function Types) [[example code](language/methods/example4/example4.go)]
- Interfaces [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/interfaces/README.md) | [notes](language/interfaces/README.md) | [exercise 1 solution](language/interfaces/exercise1/exercise1.go)]
  - Part 1 (Polymorphism) [[example code](language/interfaces/example1/example1.go)]
  - Part 2
    - Method Sets [[example code](language/interfaces/example2/example2.go)]
    - Address of Value [[example code](language/interfaces/example3/example3.go)]
  - Part 3 (Storage By Value) [[example code](language/interfaces/example4/example4.go)]
<!--  - Part 4 (Repetitive Code That Needs Polymorphism)  [[example code](language/interfaces/example0/example0.go)]
  - Part 5 (Type Assertions) [[example code](language/interfaces/example5/example5.go)]
  - Part 6 (Conditional Type Assertions) [[example code](language/interfaces/example6/example6.go)]
  - Part 7 (The Empty Interface and Type Switches) [[example code](language/interfaces/example7/example7.go)] -->
- Embedding [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/embedding/README.md) | [notes](language/embedding/README.md) | [exercise 1 solution](language/embedding/exercise1/exercise1.go) | [exercise 1 solution](language/exporting/exercise1/exercise1.go)]
  - Declaring Fields [[example code](language/embedding/example1/example1.go)]
  - Embedding types [[example code](language/embedding/example2/example2.go)]
  - Embedded types and interfaces [[example code](language/embedding/example3/example3.go)]
  - Outer and inner type interface implementations [[example code](language/embedding/example4/example4.go)]
- Exporting [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/exporting/README.md) | [notes](language/exporting/README.md)]
  - Declare and access exported identifiers - Pkg [[example code](language/exporting/example1/counters/counters.go)]
  - Declare and access exported identifiers - Main [[example code](language/exporting/example1/example1.go)]
  - Declare unexported identifiers and restrictions - Pkg [[example code](language/exporting/example2/counters/counters.go)]
  - Declare unexported identifiers and restrictions - Main [[example code](language/exporting/example2/example2.go)]
  - Access values of unexported identifiers - Pkg [[example code](language/exporting/example3/counters/counters.go)]
  - Access values of unexported identifiers - Main [[example code](language/exporting/example3/example3.go)]
  - Unexported struct type fields - Pkg [[example code](language/exporting/example4/users/users.go)]
  - Unexported struct type fields - Main [[example code](language/exporting/example4/example4.go)]
  - Unexported embedded types - Pkg [[example code](language/exporting/example5/users/users.go)]
  - Unexported embedded types - Main [[example code](language/exporting/example5/example5.go)]

### Software Design

- Topics [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/courses/go/design/README.md)]

#### Lesson 5: Composition

- Composition [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/design/composition/README.md) | [notes](design/composition/README.md) | [exercise 1 solution](design/composition/exercises/exercise1/exercise1.go)]
- Design Guidelines [[docs](https://github.com/ardanlabs/gotraining/tree/master/topics/go#interface-and-composition-design)]
- Grouping Types
  - Grouping By State [[example code](design/composition/grouping/example1/example1.go)]
  - Grouping By Behavior [[example code](design/composition/grouping/example2/example2.go)]
- Decoupling
  - Struct Composition [[example code](design/composition/decoupling/example1/example1.go)]
  - Decoupling With Interface [[example code](design/composition/decoupling/example2/example2.go)]
  - Interface Composition [[example code](design/composition/decoupling/example3/example3.go)]
  - Decoupling With Interface Composition [[example code](design/composition/decoupling/example4/example4.go)]
  - Remove Interface Pollution [[example code](design/composition/decoupling/example5/example5.go)]
  - More Precise API [[example code](design/composition/decoupling/example6/example6.go)]
- Conversion and Assertions
  - Interface Conversions [[example code](design/composition/assertions/example1/example1.go)]
  - Runtime Type Assertions [[example code](design/composition/assertions/example2/example2.go)]
  - Behavior Changes [[example code](design/composition/assertions/example3/example3.go)]
- Interface Pollution
  - Create Interface Pollution [[example code](design/composition/pollution/example1/example1.go)]
  - Remove Interface Pollution [[example code](design/composition/pollution/example2/example2.go)]
- Mocking
  - Package To Mock [[example code](design/composition/mocking/example1/pubsub/pubsub.go)]
  - Client [[example code](design/composition/mocking/example1/example1.go)]

#### Lesson 6: Error Handling

- Error Handling Design [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/design/error_handling/README.md) | [notes](design/error_handling/README.md) | [exercise 1 solution](design/error_handling/exercise1/exercise1.go) | [exercise 2 solution](design/error_handling/exercise2/exercise2.go)]
- Default Error Values [example code](design/error_handling/example1/example1.go)
- Error Variables [example code](design/error_handling/example2/example2.go)
- Type As Context [example code](design/error_handling/example3/example3.go)
- Behavior As Context [example code](design/error_handling/example4/example4.go)
- Find The Bug [example code](design/error_handling/example5/example5.go) | [the reason](design/error_handling/example5/reason/reason.go)
- Wrapping Errors [Wrapping Errors](design/error_handling/example6/example6.go)

#### Lesson 7: Packaging

- Language Mechanics [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/design/packaging/README.md#language-mechanics)]
- Design Guidelines [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/design/packaging/README.md#design-philosophy)]
- Package-Oriented Design [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/go/design/packaging/README.md#package-oriented-design)]
- [Notes](design/packaging/README.md)

### Concurrency

- Topics [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/courses/go/concurrency/README.md)]

#### Lesson 8: Mechanics - Goroutines

- Go Scheduler Internals
- Language Mechanics
- Goroutine Time Slicing
- Goroutine and Parallelism

#### Lesson 9: Mechanics - Data Races

- Data Race and Race Detection
- Synchronization with Atomic Functions
- Synchronization with Mutexes
- Read/Write Mutex
- Map Data Race
- Interface-Based Race Condition

#### Lesson 10: Mechanics - Channels

- Design Guidelines [[docs](https://github.com/ardanlabs/gotraining/tree/master/topics/go#concurrent-software-design)]
- Signaling Semantics
  - Language Mechanics | Unbuffered channel: Signaling with(out) data
  - Unbuffered channel: Double signal | Buffered channel: Close and range | Unbuffered channel: select and receive | Unbuffered channel: select and send | Buffered channel: Select and drop
- Unbuffered channel (Tennis match)
- Unbuffered channel (Replay race)
- Fan Out Pattern
- Select
- Pooling Pattern

#### Lesson 11: Concurreny Patterns

- Context
  - Store / Retrieve context values
  - WithCancel
  - WithDeadline
  - WithTimeout
  - Request/Response
- Cancellation Pattern
- Failure Detection

### Testing and Profiling

- Topics [[docs](https://github.com/ardanlabs/gotraining/blob/master/topics/courses/go/tooling/README.md)]

#### Lesson 12: Testing

- Basic Unit Testing
- Table Unit Testing
- Mocking Server
- Testing Internal Endpoints
- Sub Tests
- Code Coverage

#### Lesson 13: Benchmarking

- Basic Benchmarking
- Sub Benchmarks
- Validate Benchmarks

#### Lesson 14: Profiling and Tracing

- Profiling Guidelines
- Stack Traces
- Micro Level Optimization
- Macro Level Optimization
  - Part 1: GODEBUG Tracing
  - Part 2: Memory Profiling
  - Part 3: Tooling Changes
  - Part 4: CPU Profiling
- Execution Tracing
