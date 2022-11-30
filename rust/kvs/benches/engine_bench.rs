#[macro_use]
extern crate criterion;

use std::iter;

use criterion::{BatchSize, Criterion, ParameterizedBenchmark};
use rand::prelude::*;
use sled;
use tempfile::TempDir;
use tokio::prelude::*;

use kvs::thread_pool::RayonThreadPool;
use kvs::{KvStore, KvsEngine, SledKvsEngine};

pub fn set_bench(c: &mut Criterion) {
    let bench = ParameterizedBenchmark::new(
        "kvs",
        |b, _| {
            b.iter_batched(
                || {
                    let temp_dir = TempDir::new().unwrap();
                    let concurrency = num_cpus::get() as u32;
                    KvStore::<RayonThreadPool>::open(temp_dir.path(), concurrency).unwrap()
                },
                |engine| {
                    for i in 1..(1 << 12) {
                        engine
                            .set(format!("key{}", i), "value".to_string())
                            .wait()
                            .unwrap();
                    }
                },
                BatchSize::SmallInput,
            )
        },
        iter::once(()),
    )
    .with_function("sled", |b, _| {
        b.iter_batched(
            || {
                let tmp_dir = TempDir::new().unwrap();
                let concurrency = num_cpus::get() as u32;
                SledKvsEngine::<RayonThreadPool>::new(
                    sled::Db::open(tmp_dir.path()).unwrap(),
                    concurrency,
                )
                .unwrap()
            },
            |engine| {
                for i in 1..(1 << 12) {
                    engine
                        .set(format!("key{}", i), "value".to_string())
                        .wait()
                        .unwrap();
                }
            },
            BatchSize::SmallInput,
        )
    });
    c.bench("set_bench", bench);
}

pub fn get_bench(c: &mut Criterion) {
    let bench = ParameterizedBenchmark::new(
        "kvs",
        |b, i| {
            let temp_dir = TempDir::new().unwrap();
            let concurrency = num_cpus::get() as u32;
            let engine = KvStore::<RayonThreadPool>::open(temp_dir.path(), concurrency).unwrap();
            for key_i in 1..(1 << i) {
                engine
                    .set(format!("key{}", key_i), "value".to_string())
                    .wait()
                    .unwrap();
            }
            let mut rng = SmallRng::from_seed([0; 16]);
            b.iter(|| {
                engine
                    .get(format!("key{}", rng.gen_range(1, 1 << i)))
                    .wait()
                    .unwrap();
            });
        },
        vec![8, 12],
    )
    .with_function("sled", |b, i| {
        let tmp_dir = TempDir::new().unwrap();
        let concurrency = num_cpus::get() as u32;
        let engine = SledKvsEngine::<RayonThreadPool>::new(
            sled::Db::open(tmp_dir.path()).unwrap(),
            concurrency,
        )
        .unwrap();
        for key_i in 1..(1 << i) {
            engine
                .set(format!("key{}", key_i), "value".to_string())
                .wait()
                .unwrap();
        }
        let mut rng = SmallRng::from_seed([0; 16]);
        b.iter(|| {
            engine
                .get(format!("key{}", rng.gen_range(1, 1 << i)))
                .wait()
                .unwrap();
        })
    });
    c.bench("get_bench", bench);
}

criterion_group!(benches, set_bench, get_bench);
criterion_main!(benches);
