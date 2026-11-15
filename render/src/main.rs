mod state;

use std::env;
use std::io;
use std::net;
use std::time;

use crossterm::event;
use crossterm::terminal;
use euc::Pipeline;
use euc::Target;
use euc::buffer;
use euc::rasterizer;

const FPS: f32 = 100f32;
const POLL_RATE: f32 = time::Duration::from_secs(1).as_millis() as f32 / FPS;
const SHUTDOWN: &[u8] = "SHUTDOWN".as_bytes();
const BUFFER_SIZE: usize = u16::MAX as usize;
const WWIDTH: usize = 800;
const WHEIGHT: usize = 600;

struct Setup;

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

fn init() -> anyhow::Result<()>
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

fn shutdown() -> anyhow::Result<()>
{
     terminal::disable_raw_mode()?;

     log::info!("Shutdown");

     Ok(())
}

struct Pendulum {}

impl euc::Pipeline for Pendulum
{
     type Vertex = (glam::Vec3, glam::Vec3);

     type VsOut = (f32, f32, f32);

     type Pixel = u32;

     fn vert(&self, vertex: &Self::Vertex) -> ([f32; 4], Self::VsOut)
     {
          let (pos, col) = vertex;
          ([pos.x, pos.y, pos.z, 1.0], (col.x, col.y, col.z))
     }

     fn frag(&self, vs_out: &Self::VsOut) -> Self::Pixel
     {
          0xff_u32 << 24
               | ((vs_out.0 * 255.0).round() as u32) << 16
               | ((vs_out.1 * 255.0).round() as u32) << 8
               | (vs_out.2 * 255.0).round() as u32
     }
}

fn main() -> anyhow::Result<()>
{
     let __setup = Setup::new();

     let socket = net::UdpSocket::bind("127.0.0.1:6767")?;
     socket.set_read_timeout(Some(time::Duration::from_millis(POLL_RATE as u64)))?;

     let mut window = minifb::Window::new("Zendulum", WWIDTH, WHEIGHT, minifb::WindowOptions::default())?;
     let mut color = buffer::Buffer2d::new([WWIDTH, WHEIGHT], 0u32);
     let mut depth = buffer::Buffer2d::new([WWIDTH, WHEIGHT], 1.0f32);

     let mut buffer = [0u8; BUFFER_SIZE];
     loop
     {
          color.clear(0u32);
          depth.clear(1.0f32);
          Pendulum {}.draw::<rasterizer::Triangles<_>, _>(
               &[
                    (glam::Vec3::new(-0.5, -0.5, 0.0), glam::Vec3::new(1.0, 0.0, 0.0)),
                    (glam::Vec3::new(0.5, -0.5, 0.0), glam::Vec3::new(0.0, 1.0, 0.0)),
                    (glam::Vec3::new(0.0, 0.5, 0.0), glam::Vec3::new(0.0, 0.0, 1.0)),
               ],
               &mut color,
               Some(&mut depth),
          );
          window.update_with_buffer(color.as_ref(), color.size()[0], color.size()[1])?;

          match socket.recv(&mut buffer)
          {
               | Ok(len) =>
               {
                    let recv = &buffer[0 .. len];
                    if recv == SHUTDOWN
                    {
                         break;
                    }

                    let string = str::from_utf8(recv)?;
                    println!("Recieved this stuff: {:?}\nAs string: {}", recv, string);
               }
               | Err(err) =>
               {
                    if err.kind() != io::ErrorKind::WouldBlock && err.kind() != io::ErrorKind::TimedOut
                    {
                         log::error!("I/O error: {}", err);
                         return Err(err.into());
                    }
               }
          }

          if event::poll(time::Duration::ZERO)?
               && let event::Event::Key(key) = event::read()?
               && key.code.is_esc()
          {
               break;
          }
          if window.is_key_down(minifb::Key::Escape)
          {
               break;
          }
     }

     Ok(())
}
