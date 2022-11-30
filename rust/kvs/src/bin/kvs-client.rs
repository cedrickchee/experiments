use std::process::exit;
use structopt::StructOpt;
use tokio::prelude::*;

use kvs::{KvsClient, Result};

mod cli;
use cli::{Options, SubCommand};

fn main() {
    let opts = Options::from_args();
    if let Err(e) = run(opts) {
        eprintln!("{}", e);
        exit(1);
    }
}

fn run(opts: Options) -> Result<()> {
    match opts.cmd {
        SubCommand::Get { key, addr } => {
            let client = KvsClient::connect(addr);

            let output = match client.and_then(move |client| client.get(key)).wait()? {
                (Some(value), _) => value,
                (None, _) => "Key not found".to_string(),
            };

            println!("{}", output);
        }
        SubCommand::Set { key, value, addr } => {
            let client = KvsClient::connect(addr);
            client
                .and_then(move |client| client.set(key, value))
                .wait()?;
        }
        SubCommand::Rm { key, addr } => {
            let client = KvsClient::connect(addr);
            client.and_then(move |client| client.remove(key)).wait()?;
        }
    }
    Ok(())
}
