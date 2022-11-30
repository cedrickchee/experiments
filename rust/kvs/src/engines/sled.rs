use sled::Db;
use tokio::prelude::*;
use tokio::sync::oneshot;

use super::KvsEngine;
use crate::thread_pool::ThreadPool;
use crate::{KvsError, Result};

/// Wrapper of `sled::Db`.
#[derive(Clone)]
pub struct SledKvsEngine<P: ThreadPool> {
    db: Db,
    thread_pool: P,
}

impl<P: ThreadPool> SledKvsEngine<P> {
    /// Creates a `SledKvsEngine` from `sled::Db`.
    ///
    /// Operations are run in the given thread pool. `concurrency` specifies the number of
    /// threads in the thread pool.
    pub fn new(db: Db, concurrency: u32) -> Result<Self> {
        let thread_pool = P::new(concurrency)?;
        Ok(Self { db, thread_pool })
    }
}

impl<P: ThreadPool> KvsEngine for SledKvsEngine<P> {
    fn set(
        &self,
        key: String,
        value: String,
    ) -> Box<dyn Future<Item = (), Error = KvsError> + Send> {
        let db = self.db.clone();
        let (tx, rx) = oneshot::channel();
        self.thread_pool.spawn(move || {
            let res = db
                .insert(key, value.into_bytes())
                .and_then(|_| db.flush())
                .map(|_| ())
                .map_err(KvsError::from);
            if tx.send(res).is_err() {
                error!("Receiving end is dropped");
            }
        });
        Box::new(
            rx.map_err(|e| KvsError::StringError(format!("{}", e)))
                .flatten(),
        )
    }

    fn get(&self, key: String) -> Box<dyn Future<Item = Option<String>, Error = KvsError> + Send> {
        let db = self.db.clone();
        let (tx, rx) = oneshot::channel();
        self.thread_pool.spawn(move || {
            let res = (move || {
                Ok(db
                    .get(key)?
                    .map(|i_vec| AsRef::<[u8]>::as_ref(&i_vec).to_vec())
                    .map(String::from_utf8)
                    .transpose()?)
            })();
            if tx.send(res).is_err() {
                error!("Receiving end is dropped");
            }
        });
        Box::new(
            rx.map_err(|e| KvsError::StringError(format!("{}", e)))
                .flatten(),
        )
    }

    fn remove(&self, key: String) -> Box<dyn Future<Item = (), Error = KvsError> + Send> {
        let db = self.db.clone();
        let (tx, rx) = oneshot::channel();
        self.thread_pool.spawn(move || {
            let res = (move || {
                db.remove(key)?.ok_or(KvsError::KeyNotFound)?;
                db.flush()?;
                Ok(())
            })();
            if tx.send(res).is_err() {
                error!("Receiving end is dropped");
            }
        });
        Box::new(
            rx.map_err(|e| KvsError::StringError(format!("{}", e)))
                .flatten(),
        )
    }
}
