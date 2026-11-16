use glam::camera::rh::proj::directx;
use glam::camera::rh::view;

#[derive(Debug, Default, Clone, Copy)]
pub struct Camera
{
     pub pos: glam::Vec3,
     pub target: glam::Vec3,
     pub ar: f32,
     pub fov: f32,
     pub zl: f32,
     pub zh: f32,
     pub pitch: f32,
     pub yaw: f32,
}

impl Camera
{
     pub fn true_mvp(&self) -> glam::Mat4
     {
          self.proj() * self.true_view()
     }

     pub fn orbit_mvp(&self) -> glam::Mat4
     {
          self.proj() * self.orbit_view()
     }

     pub fn true_view(&self) -> glam::Mat4
     {
          glam::Mat4::from_rotation_translation(
               glam::Quat::from_euler(
                    glam::EulerRot::ZYX,
                    0.0,
                    self.yaw.to_radians(),
                    self.pitch.to_radians(),
               ),
               self.pos,
          )
     }

     pub fn orbit_view(&self) -> glam::Mat4
     {
          let dist = (self.pos - self.target).length();
          let (pitch, yaw) = (self.pitch.to_radians(), self.yaw.to_radians());

          let x = dist * pitch.cos() * yaw.sin();
          let y = dist * pitch.sin();
          let z = dist * pitch.cos() * yaw.cos();

          view::look_at_mat4(self.target + glam::vec3(x, y, z), self.target, glam::Vec3::Y)
     }

     pub fn proj(&self) -> glam::Mat4
     {
          directx::perspective(self.fov.to_radians(), self.ar, self.zl, self.zh)
     }
}
