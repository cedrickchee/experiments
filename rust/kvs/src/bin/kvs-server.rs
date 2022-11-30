#[macro_use]
extern crate log;

use std::env;
use std::fs;
use std::net::SocketAddr;
use std::process::exit;

use log::LevelFilter;
use structopt::clap::arg_enum;
use structopt::StructOpt;

use kvs::thread_pool::RayonThreadPool;
use kvs::{KvStore, KvsEngine, KvsServer, Result, SledKvsEngine};

const DEFAULT_LISTENING_ADDRESS: &str = "127.0.0.1:4000";
const DEFAULT_ENGINE: Engine = Engine::Kvs;

// A struct to hold command line arguments parsed.
#[derive(StructOpt, Debug)]
#[structopt(name = "kvs-server")]
pub struct Options {
    /// Sets the listening address
    #[structopt(long, value_name = "IP:PORT", default_value = DEFAULT_LISTENING_ADDRESS, parse(try_from_str))]
    addr: SocketAddr,
    /// Sets the storage engine
    #[structopt(
        long,
        value_name = "ENGINE-NAME",
        case_insensitive = true,
        possible_values = &Engine::variants()
    )]
    engine: Option<Engine>,
}

arg_enum! {
    #[derive(Debug, PartialEq, Eq, Copy, Clone)]
    enum Engine {
        Kvs,
        Sled,
    }
}

fn main() {
    env_logger::builder()
        .filter_level(LevelFilter::Debug)
        .init();

    let mut opts = Options::from_args();

    let res = current_engine().and_then(move |curr_engine| {
        if opts.engine.is_none() {
            opts.engine = curr_engine;
        }
        if curr_engine.is_some() && opts.engine != curr_engine {
            error!("Wrong engine!");
            exit(1);
        }
        run(opts)
    });

    if let Err(e) = res {
        error!("{}", e);
        exit(1)
    }
}

fn run(opt: Options) -> Result<()> {
    let engine = opt.engine.unwrap_or(DEFAULT_ENGINE);
    info!("kvs-server {}", env!("CARGO_PKG_VERSION"));
    info!("Storage engine: {}", engine);
    info!("Listening on {}", opt.addr);

    // Write engine to file.
    fs::write(env::current_dir()?.join("engine"), format!("{}", engine))?;

    let concurrency = num_cpus::get() as u32;

    match engine {
        Engine::Kvs => run_with(
            KvStore::<RayonThreadPool>::open(env::current_dir()?, concurrency)?,
            opt.addr,
        )?,
        Engine::Sled => run_with(
            SledKvsEngine::<RayonThreadPool>::new(
                sled::Db::open(env::current_dir()?)?,
                concurrency,
            )?,
            opt.addr,
        )?,
    }

    Ok(())
}

fn run_with<E: KvsEngine>(engine: E, addr: SocketAddr) -> Result<()> {
    // The trait `KvsEngine` is implemented for `KvStore`. So, the trait
    // bound `KvStore: KvsEngine` is satisfied.
    let server = KvsServer::new(engine);
    server.run(addr)
}

fn current_engine() -> Result<Option<Engine>> {
    let engine = env::current_dir()?.join("engine");
    if !engine.exists() {
        return Ok(None);
    }

    match fs::read_to_string(engine)?.parse() {
        Ok(engine) => Ok(Some(engine)),
        Err(err) => {
            warn!("The content of engine file is invalid: {}", err);
            Ok(None)
        }
    }
}
