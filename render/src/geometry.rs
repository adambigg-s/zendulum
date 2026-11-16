#[repr(C)]
#[derive(bytemuck::Pod, bytemuck::Zeroable, Debug, Default, Clone, Copy)]
pub struct SimpleVertex
{
     pub pos: glam::Vec3,
     pub col: glam::Vec3,
     pub nor: glam::Vec3,
}

#[derive(Debug, Default, Clone)]
pub struct Cuboid
{
     pub transform: glam::Mat4,
     pub vertices: Vec<SimpleVertex>,
     pub indices: Vec<u32>,
}

impl Cuboid
{
     pub fn new(color: glam::Vec3, scale: glam::Vec3) -> Self
     {
          let (raw_verts, raw_inds) = make_cuboid_parts(color);

          todo!()
     }
}

pub fn make_cuboid_parts(col: glam::Vec3) -> (Vec<SimpleVertex>, Vec<u32>)
{
     let v = glam::vec3;
     let h = 0.5f32;

     let nx = v(1.0, 0.0, 0.0);
     let ny = v(0.0, 1.0, 0.0);
     let nz = v(0.0, 0.0, 1.0);

     #[rustfmt::skip]
     let pos = [
          v(-h, -h,  h), v( h, -h,  h), v( h,  h,  h), v(-h,  h,  h),
          v( h, -h, -h), v(-h, -h, -h), v(-h,  h, -h), v( h,  h, -h),
          v(-h, -h, -h), v(-h, -h,  h), v(-h,  h,  h), v(-h,  h, -h),
          v( h, -h,  h), v( h, -h, -h), v( h,  h, -h), v( h,  h,  h),
          v(-h,  h,  h), v( h,  h,  h), v( h,  h, -h), v(-h,  h, -h),
          v(-h, -h, -h), v( h, -h, -h), v( h, -h,  h), v(-h, -h,  h),
     ];

     #[rustfmt::skip]
     let nor = [
           nz,  nz,  nz,  nz,
          -nz, -nz, -nz, -nz,
          -nx, -nx, -nx, -nx,
           nx,  nx,  nx,  nx,
           ny,  ny,  ny,  ny,
          -ny, -ny, -ny, -ny,
     ];

     (
          pos.iter()
               .zip(nor.iter())
               .map(|(&pos, &nor)| {
                    SimpleVertex {
                         pos,
                         col,
                         nor,
                    }
               })
               .collect(),
          (0 .. 6)
               .flat_map(|idx| {
                    [
                         idx * 4,
                         idx * 4 + 1,
                         idx * 4 + 2,
                         idx * 4,
                         idx * 4 + 2,
                         idx * 4 + 3,
                    ]
               })
               .collect(),
     )
}
