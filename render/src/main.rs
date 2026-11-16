pub mod camera;
pub mod config;
pub mod geometry;
pub mod state;

use std::io;
use std::net;
use std::time;

use crossterm::event;
use euc::Pipeline;
use euc::Target;
use euc::buffer;
use euc::rasterizer;

const WWIDTH: usize = 800;
const WHEIGHT: usize = 600;
const SHUTDOWN: &[u8] = "SHUTDOWN".as_bytes();
const BUFFER_SIZE: usize = u16::MAX as usize;
const FPS: f32 = 240f32;
const POLL_RATE: f32 = time::Duration::from_secs(1).as_millis() as f32 / FPS;
const BACKGROUND_COLOR: u32 = 0xffu32 << 24 | 180u32 << 16 | 180u32 << 8 | 180u32;

struct SimulationState
{
     state: state::State,
     camera: camera::Camera,
     bodies: Vec<geometry::Cuboid>,
}

impl SimulationState
{
     fn build_pendulum(&mut self)
     {
          self.bodies
               .push(geometry::Cuboid::new(glam::vec3(1.0, 0.0, 0.0), glam::vec3(0.15, 0.15, 0.15)));
          self.bodies
               .push(geometry::Cuboid::new(glam::vec3(1.0, 0.5, 0.5), glam::vec3(0.1, 2.0, 0.1)));
          self.bodies
               .push(geometry::Cuboid::new(glam::vec3(0.0, 0.0, 1.0), glam::vec3(0.5, 0.5, 0.5)));
     }

     fn update_pendulum(&mut self)
     {
          let swing = glam::Mat4::from_rotation_z(self.state.theta1 as f32);
          let length = self.bodies[1].size.y;
          let pivot = glam::Mat4::from_translation(glam::vec3(0.0, -length * 0.5, 0.0));

          self.bodies[0].transform = pivot;
          self.bodies[1].transform =
               pivot * swing * glam::Mat4::from_translation(glam::vec3(0.0, -length / 2.0, 0.0));
          self.bodies[2].transform =
               pivot * swing * glam::Mat4::from_translation(glam::vec3(0.0, -length, 0.0));
     }
}

struct PendulumPipeline
{
     proj: glam::Mat4,
     view: glam::Mat4,
     model: glam::Mat4,
}

impl euc::Pipeline for PendulumPipeline
{
     type Vertex = geometry::SimpleVertex;

     type VsOut = ((f32, f32, f32), (f32, f32, f32));

     type Pixel = u32;

     fn vert(&self, vertex: &Self::Vertex) -> ([f32; 4], Self::VsOut)
     {
          let out_pos =
               self.proj * self.view * self.model * glam::vec4(vertex.pos.x, vertex.pos.y, vertex.pos.z, 1.0);
          let out_nor = (self.model * glam::vec4(vertex.nor.x, vertex.nor.y, vertex.nor.z, 0.0))
               .truncate()
               .normalize();

          (
               [out_pos.x, out_pos.y, out_pos.z, out_pos.w],
               ((vertex.col.x, vertex.col.y, vertex.col.z), (out_nor.x, out_nor.y, out_nor.z)),
          )
     }

     fn frag(&self, vs_out: &Self::VsOut) -> Self::Pixel
     {
          let (col, nor) = vs_out;
          let (mut r, mut g, mut b) = *col;
          let (nx, ny, nz) = *nor;

          let shading = glam::vec3(nx, ny, nz).dot(glam::vec3(0.5, 1.0, 0.5).normalize()).clamp(0.1, 1.0);
          r *= shading;
          g *= shading;
          b *= shading;

          0xffu32 << 24
               | ((r * 255.0).round() as u8 as u32) << 16
               | ((g * 255.0).round() as u8 as u32) << 8
               | ((b * 255.0).round() as u8 as u32) << 4 >> 4
     }
}

fn main() -> anyhow::Result<()>
{
     let __setup = config::Setup::new();

     let mut udp_buffer = [0u8; BUFFER_SIZE];
     let socket = net::UdpSocket::bind("127.0.0.1:6767")?;
     socket.set_read_timeout(Some(time::Duration::from_millis(POLL_RATE as u64)))?;
     socket.set_nonblocking(true)?;

     let mut window = minifb::Window::new(
          "Zendulum",
          WWIDTH,
          WHEIGHT,
          minifb::WindowOptions {
               scale: minifb::Scale::X1,
               ..Default::default()
          },
     )?;
     window.set_target_fps(FPS as usize + 1);

     let mut color = buffer::Buffer2d::new([WWIDTH, WHEIGHT], 0u32);
     let mut depth = buffer::Buffer2d::new([WWIDTH, WHEIGHT], 1.0f32);

     let camera = camera::Camera {
          pos: glam::vec3(0.0, 0.0, 5.0),
          target: glam::Vec3::ZERO,
          ar: color.size()[0] as f32 / color.size()[1] as f32,
          fov: 70.0,
          zl: 0.01,
          zh: 100.0,
          pitch: 0.0,
          yaw: 0.0,
          fvec: glam::Vec3::X,
          mode: camera::Mode::Orbit,
          ..Default::default()
     };

     let mut state = SimulationState {
          state: state::State::default(),
          camera,
          bodies: Vec::new(),
     };
     state.build_pendulum();

     loop
     {
          color.clear(BACKGROUND_COLOR);
          depth.clear(1.0f32);

          state.camera.update_vectors();

          state.update_pendulum();
          state.bodies.iter().for_each(|body| {
               PendulumPipeline {
                    proj: state.camera.proj(),
                    view: state.camera.view(),
                    model: body.transform,
               }
               .draw::<rasterizer::Triangles<_, rasterizer::BackfaceCullingDisabled>, _>(
                    &body.vertices,
                    &mut color,
                    Some(&mut depth),
               );
          });

          window.update_with_buffer(color.as_ref(), color.size()[0], color.size()[1])?;

          if window.is_key_down(minifb::Key::W)
          {
               state.camera.pitch += 1.0;
          }
          if window.is_key_down(minifb::Key::S)
          {
               state.camera.pitch -= 1.0;
          }
          if window.is_key_down(minifb::Key::A)
          {
               state.camera.yaw -= 1.0;
          }
          if window.is_key_down(minifb::Key::D)
          {
               state.camera.yaw += 1.0;
          }
          if window.is_key_down(minifb::Key::R)
          {
               state.camera.pos -= glam::Vec3::Z * 0.1;
          }
          if window.is_key_down(minifb::Key::F)
          {
               state.camera.pos += glam::Vec3::Z * 0.1;
          }

          match socket.recv(&mut udp_buffer)
          {
               | Ok(len) =>
               {
                    let recv = &udp_buffer[0 .. len];
                    if recv == SHUTDOWN
                    {
                         break;
                    }

                    if let Ok(string) = str::from_utf8(recv)
                    {
                         println!("Recieved this stuff: {:?}\nAs string: {}", recv, string)
                    }

                    state.state = match state::State::parse_bytes(recv)
                    {
                         | Ok(state) => state,
                         | Err(err) =>
                         {
                              log::error!("{}", err);
                              state.state
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
