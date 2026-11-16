mod camera;
mod config;
mod geometry;
mod state;

use std::io;
use std::net;
use std::time;

use crossterm::event;
use euc::Pipeline;
use euc::Target;
use euc::buffer;
use euc::rasterizer;

const FPS: f32 = 240f32;
const POLL_RATE: f32 = time::Duration::from_secs(1).as_millis() as f32 / FPS;
const SHUTDOWN: &[u8] = "SHUTDOWN".as_bytes();
const BUFFER_SIZE: usize = u16::MAX as usize;
const WWIDTH: usize = 800;
const WHEIGHT: usize = 600;

struct SimulationState
{
     state: state::State,
     bodies: Vec<geometry::Cuboid>,
}

struct PendulumPipeline
{
     state: state::State,
     camera: camera::Camera,
     model: glam::Mat4,
}

impl euc::Pipeline for PendulumPipeline
{
     type Vertex = geometry::SimpleVertex;

     type VsOut = (f32, f32, f32);

     type Pixel = u32;

     fn vert(&self, vertex: &Self::Vertex) -> ([f32; 4], Self::VsOut)
     {
          let geometry::SimpleVertex {
               pos,
               col,
               nor,
          } = vertex;
          let out_pos = self.camera.orbit_mvp() * glam::vec4(pos.x, pos.y, pos.z, 1.0);
          ([out_pos.x, out_pos.y, out_pos.z, out_pos.w], (col.x, col.y, col.z))
     }

     fn frag(&self, vs_out: &Self::VsOut) -> Self::Pixel
     {
          let (r, g, b) = vs_out;
          0xff_u32 << 24
               | ((r * 255.0).round() as u8 as u32) << 16
               | ((g * 255.0).round() as u8 as u32) << 8
               | ((b * 255.0).round() as u8 as u32) << 4 >> 4
     }
}

fn main() -> anyhow::Result<()>
{
     let __setup = config::Setup::new();

     let socket = net::UdpSocket::bind("127.0.0.1:6767")?;
     socket.set_read_timeout(Some(time::Duration::from_millis(POLL_RATE as u64)))?;

     let mut window = minifb::Window::new("Zendulum", WWIDTH, WHEIGHT, minifb::WindowOptions::default())?;
     let mut color = buffer::Buffer2d::new([WWIDTH, WHEIGHT], 0u32);
     let mut depth = buffer::Buffer2d::new([WWIDTH, WHEIGHT], 1.0f32);
     let mut camera = camera::Camera {
          pos: glam::vec3(0.0, 0.0, 5.0),
          target: glam::Vec3::ZERO,
          ar: color.size()[0] as f32 / color.size()[1] as f32,
          fov: 70.0,
          zl: 0.01,
          zh: 100.0,
          pitch: 0.0,
          yaw: 0.0,
     };
     let mut state = state::State {
          theta1: 0.0,
          theta2: 0.0,
          dtheta1: 0.0,
          dtheta2: 0.0,
     };

     let mut buffer = [0u8; BUFFER_SIZE];
     loop
     {
          color.clear(0u32);
          depth.clear(1.0f32);

          let (verts, inds) = &geometry::make_cuboid_parts(glam::vec3(1.0, 0.0, 0.0));
          PendulumPipeline {
               state,
               camera,
          }
          .draw::<rasterizer::Triangles<_, rasterizer::BackfaceCullingDisabled>, _>(
               &inds.iter().map(|&ind| verts[ind as usize]).collect::<Vec<_>>(),
               &mut color,
               Some(&mut depth),
          );
          window.update_with_buffer(color.as_ref(), color.size()[0], color.size()[1])?;

          if window.is_key_down(minifb::Key::W)
          {
               camera.pitch += 3.0;
          }
          if window.is_key_down(minifb::Key::S)
          {
               camera.pitch -= 3.0;
          }
          if window.is_key_down(minifb::Key::A)
          {
               camera.yaw += 3.0;
          }
          if window.is_key_down(minifb::Key::D)
          {
               camera.yaw -= 3.0;
          }
          if window.is_key_down(minifb::Key::R)
          {
               camera.pos += glam::Vec3::Z * 0.1;
          }
          if window.is_key_down(minifb::Key::F)
          {
               camera.pos -= glam::Vec3::Z * 0.1;
          }

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

                    state = match state::State::parse_bytes(recv)
                    {
                         | Ok(state) => state,
                         | Err(err) =>
                         {
                              log::error!("{}", err);
                              state
                         }
                    };
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
