# KVS ([Key-Value][kv] Store)

KVS is a project to practice systems software development in Rust.

KVS is **a simple [log-structured storage][log-storage]**, inspired by [Bitcask].
It is a single networked, multi-threaded, and async Rust program.

Creating this program provide me a chance to exercise the best of the Rust
ecosystem, interesting language features, the world of async Rust, a variety
of concurrent data types, and Rust tools.

**The goal**

After completing this project, I want to have the knowledge and experience to
begin building systems program, with all the desirable Rust characteristics,
including reliability, easy concurrency, and performance.

As a newcomer, I **want to learn**:

- Design and implementation of [database systems theory][dbdev]
  - Build an in-memory key-value store
  - Log-structured file I/O — build a persistent key-value store, log compaction
    (to remove stale data)
  - Write a fully-functional database
- Structuring and maintaining Rust programs
- Rust idioms
- Best practices in Rust
- Learn to debug the type system
- Applying common tools like [rustfmt]
- Asyncronous programming with Rust [futures]
- Network programming with std and [tokio]
  - Create a key-value server and client and communicate with a custom
    networking protocol
  - Asynchronous networking with the tokio runtime
- Concurrent programming, parallel programming with [crossbeam]
  - Write a simple thread pool
  - Cross-thread communication using channels
  - Share data structures with locks, read operations without locks (lock-free data structures, atomics)
- Serialization with [serde]
- Benchmarking with [criterion]
  - Comparing the performance of my key-value store to others, like [sled], [bitcask], [badger], or [RocksDB]

[kv]: https://en.wikipedia.org/wiki/Key-value_database
[log-storage]: https://jvns.ca/blog/2017/06/11/log-structured-storage/
[bitcask]: https://github.com/basho/bitcask/blob/develop/doc/bitcask-intro.pdf
[dbdev]: https://15445.courses.cs.cmu.edu/fall2019/
[rustfmt]: https://github.com/rust-lang/rustfmt/

[serde]: https://github.com/serde-rs/serde
[tokio]: https://github.com/tokio-rs/tokio
[criterion]: https://github.com/bheisler/criterion.rs
[crossbeam]: https://github.com/crossbeam-rs/crossbeam
[futures]: https://docs.rs/futures/0.1.27/futures/

[sled]: https://github.com/spacejam/sled
[badger]: https://github.com/dgraph-io/badger
[RocksDB]: https://rocksdb.org/