use std::env;

use crossterm::terminal;

pub struct Setup;

impl Setup
{
     pub fn new() -> Self
     {
          init().unwrap();
          Self
     }
}

impl Drop for Setup
{
     fn drop(&mut self)
     {
          shutdown().unwrap();
     }
}

pub fn init() -> anyhow::Result<()>
{
     unsafe {
          env::set_var("RUST_BACKTRACE", "full");
          env::set_var("RUST_LOG", "debug");
     }
     env_logger::init();

     terminal::enable_raw_mode()?;

     log::info!("Initialized");

     Ok(())
}

pub fn shutdown() -> anyhow::Result<()>
{
     terminal::disable_raw_mode()?;

     log::info!("Shutdown");

     Ok(())
}
