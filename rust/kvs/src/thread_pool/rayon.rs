use std::sync::Arc;

use super::ThreadPool;
use crate::{KvsError, Result};

/// Wrapper of rayon::ThreadPool
#[derive(Clone)]
pub struct RayonThreadPool(Arc<rayon::ThreadPool>);

impl ThreadPool for RayonThreadPool {
    fn new(threads: u32) -> Result<Self> {
        let thread_pool = rayon::ThreadPoolBuilder::new()
            .num_threads(threads as usize)
            .build()
            .map_err(|err| KvsError::StringError(format!("{}", err)))?;

        Ok(Self(Arc::new(thread_pool)))
    }

    fn spawn<F>(&self, job: F)
    where
        F: FnOnce() + Send + 'static,
    {
        self.0.spawn(job)
    }
}
