use glam::camera::rh::proj::directx;
use glam::camera::rh::view;

#[derive(Debug, Default, Clone, Copy)]
pub enum Mode
{
     #[default]
     Linear,
     Orbit,
}

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
     pub rvec: glam::Vec3,
     pub fvec: glam::Vec3,
     pub uvec: glam::Vec3,
     pub mode: Mode,
}

impl Camera
{
     pub fn mvp(&self) -> glam::Mat4
     {
          match self.mode
          {
               | Mode::Linear => self.true_mvp(),
               | Mode::Orbit => self.orbit_mvp(),
          }
     }

     pub fn view(&self) -> glam::Mat4
     {
          match self.mode
          {
               | Mode::Linear => self.true_view(),
               | Mode::Orbit => self.orbit_view(),
          }
     }

     pub fn proj(&self) -> glam::Mat4
     {
          directx::perspective(self.fov.to_radians(), self.ar, self.zl, self.zh)
     }

     pub fn update_vectors(&mut self)
     {
          match self.mode
          {
               | Mode::Linear => self.update_vectors_true(),
               | Mode::Orbit => self.update_vectors_orbit(),
          }
     }

     fn true_mvp(&self) -> glam::Mat4
     {
          self.proj() * self.true_view()
     }

     fn orbit_mvp(&self) -> glam::Mat4
     {
          self.proj() * self.orbit_view()
     }

     fn true_view(&self) -> glam::Mat4
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

     fn orbit_view(&self) -> glam::Mat4
     {
          let dist = (self.pos - self.target).length();
          let (pitch, yaw) = (self.pitch.clamp(-89.0, 89.0).to_radians(), self.yaw.to_radians());

          let x = dist * pitch.cos() * yaw.sin();
          let y = dist * pitch.sin();
          let z = dist * pitch.cos() * yaw.cos();

          view::look_at_mat4(self.target + glam::vec3(x, y, z), self.target, glam::Vec3::Y)
     }

     fn update_vectors_true(&mut self)
     {
          let quat = glam::Quat::from_euler(
               glam::EulerRot::ZYX,
               0.0,
               self.yaw.to_radians(),
               self.pitch.to_radians(),
          );

          self.rvec = quat * glam::Vec3::X;
          self.fvec = quat * glam::Vec3::NEG_Z;
          self.uvec = quat * glam::Vec3::Y;
     }

     fn update_vectors_orbit(&mut self)
     {
          let dist = (self.pos - self.target).length();
          let (pitch, yaw) = (self.pitch.clamp(-89.0, 89.0).to_radians(), self.yaw.to_radians());

          let x = dist * pitch.cos() * yaw.sin();
          let y = dist * pitch.sin();
          let z = dist * pitch.cos() * yaw.cos();

          let eye = self.target + glam::vec3(x, y, z);

          self.fvec = (self.target - eye).normalize();
          self.rvec = self.fvec.cross(glam::Vec3::Y).normalize();
          self.uvec = self.rvec.cross(self.fvec).normalize();
     }
}
