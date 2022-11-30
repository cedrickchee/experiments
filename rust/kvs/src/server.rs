use std::net::SocketAddr;

use tokio::codec::{FramedRead, FramedWrite, LengthDelimitedCodec};
use tokio::net::{TcpListener, TcpStream};
use tokio::prelude::*;
use tokio_serde_json::{ReadJson, WriteJson};

use crate::common::{Request, Response};
use crate::{KvsEngine, KvsError, Result};

/// The server of a key value store.
pub struct KvsServer<E: KvsEngine> {
    engine: E,
}

impl<E: KvsEngine> KvsServer<E> {
    /// Create a `KvsServer` with a given storage engine.
    pub fn new(engine: E) -> Self {
        Self { engine }
    }

    /// Run the server listening on the given address
    pub fn run(self, addr: SocketAddr) -> Result<()> {
        let listener = TcpListener::bind(&addr)?;

        // Pull out a stream of sockets for incoming connections
        let server = listener
            .incoming()
            .map_err(|e| error!("Unable to connect: {}", e))
            .for_each(move |stream| {
                debug!("Connection established");
                let engine = self.engine.clone();
                serve(engine, stream).map_err(|e| error!("Error on serving client: {}", e))
            });

        // Start the Tokio runtime
        tokio::run(server);

        Ok(())
    }
}

fn serve<E: KvsEngine>(engine: E, tcp: TcpStream) -> impl Future<Item = (), Error = KvsError> {
    let (read_half, write_half) = tcp.split();
    let read_json = ReadJson::new(FramedRead::new(read_half, LengthDelimitedCodec::new()));
    let write_json = WriteJson::new(FramedWrite::new(write_half, LengthDelimitedCodec::new()));
    write_json
        .sink_map_err(|e| e.into())
        .send_all(read_json.map_err(|e| e.into()).and_then(
            move |req| -> Box<dyn Future<Item = Response, Error = KvsError> + Send> {
                match req {
                    Request::Set { key, value } => {
                        Box::new(engine.set(key, value).map(|_| Response::Set))
                    }
                    Request::Get { key } => Box::new(engine.get(key).map(Response::Get)),
                    Request::Remove { key } => {
                        Box::new(engine.remove(key).map(|_| Response::Remove))
                    }
                }
            },
        ))
        .map(|_| ())
}
