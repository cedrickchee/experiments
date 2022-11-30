//! # Kvs
//!
//! A simple in-memory key/value store

#![deny(missing_docs)]

#[macro_use]
extern crate log;

mod client;
mod common;
mod engines;
mod error;
mod server;
pub mod thread_pool;

pub use client::KvsClient;
pub use engines::{KvStore, KvsEngine, SledKvsEngine};
pub use error::{KvsError, Result};
pub use server::KvsServer;
