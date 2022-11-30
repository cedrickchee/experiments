use failure::Fail;
use std::io;
use std::string;

/// Error type. It represents the ways a kvs could be invalid.
#[derive(Fail, Debug)]
pub enum KvsError {
    /// An IO error. Wraps a `std::io::Error`.
    #[fail(display = "IO error: {}", _0)]
    Io(#[fail(cause)] io::Error),
    /// Serialization or deserialization error.
    #[fail(display = "serde_json error: {}", _0)]
    Serde(#[fail(cause)] serde_json::Error),
    /// Removing non-existent key error.
    #[fail(display = "Key not found")]
    KeyNotFound,
    /// Unexpected command type error.
    /// It indicated a corrupted log or a program bug.
    #[fail(display = "Unexpected command type")]
    UnexpectedCommandType,
    /// Error with a string message.
    #[fail(display = "{}", _0)]
    StringError(String),
    /// Sled error.
    #[fail(display = "sled error: {}", _0)]
    Sled(#[fail(cause)] sled::Error),
    /// Utf8 error.
    #[fail(display = "UTF-8 error: {}", _0)]
    Utf8(#[fail(cause)] string::FromUtf8Error),
}

impl From<io::Error> for KvsError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

impl From<serde_json::Error> for KvsError {
    fn from(error: serde_json::Error) -> Self {
        Self::Serde(error)
    }
}

impl From<sled::Error> for KvsError {
    fn from(error: sled::Error) -> Self {
        Self::Sled(error)
    }
}

impl From<string::FromUtf8Error> for KvsError {
    fn from(error: string::FromUtf8Error) -> Self {
        Self::Utf8(error)
    }
}

/// Result type.
pub type Result<T> = std::result::Result<T, KvsError>;
