use std::net::SocketAddr;
use structopt::StructOpt;

// A struct to hold command line arguments parsed.
#[derive(StructOpt, Debug)]
#[structopt(name = "kvs-client")]
pub struct Options {
    #[structopt(subcommand)]
    pub cmd: SubCommand,
}

#[derive(StructOpt, Debug)]
pub enum SubCommand {
    /// Get the string value of a given string key
    Get {
        #[structopt(name = "KEY", required = true)]
        /// A string key
        key: String,
        /// Sets the server address
        #[structopt(long, value_name = "IP:PORT", default_value = "127.0.0.1:4000")]
        addr: SocketAddr,
    },
    /// Set the value of a string key to a string
    Set {
        #[structopt(name = "KEY", required = true)]
        /// A string key
        key: String,
        #[structopt(name = "VALUE", required = true)]
        /// The string value of the key
        value: String,
        /// Sets the server address
        #[structopt(long, value_name = "IP:PORT", default_value = "127.0.0.1:4000")]
        addr: SocketAddr,
    },
    /// Remove a given key
    Rm {
        #[structopt(name = "KEY", required = true)]
        /// A string key
        key: String,
        /// Sets the server address
        #[structopt(long, value_name = "IP:PORT", default_value = "127.0.0.1:4000")]
        addr: SocketAddr,
    },
}
