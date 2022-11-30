use tokio::prelude::Future;

use crate::KvsError;

/// Trait for a key value storage engine.
pub trait KvsEngine: Clone + Send + 'static {
    /// Set the value of a string key to a string.
    ///
    /// Returns an error if the value is not written successfully.
    /// If the key already exists, the previous value will be overwritten.
    fn set(
        &self,
        key: String,
        value: String,
    ) -> Box<dyn Future<Item = (), Error = KvsError> + Send>;

    /// Get the string value of a string key.
    ///
    /// If the key does not exist, return `None`.
    /// Returns an error if the value is not read successfully.
    fn get(&self, key: String) -> Box<dyn Future<Item = Option<String>, Error = KvsError> + Send>;

    /// Remove a given string key.
    ///
    /// Returns `KvsError::KeyNotFound` error if the given key does not exit
    /// or value is not read successfully.
    fn remove(&self, key: String) -> Box<dyn Future<Item = (), Error = KvsError> + Send>;
}

mod kvs;
mod sled;

pub use self::kvs::KvStore;
pub use self::sled::SledKvsEngine;
