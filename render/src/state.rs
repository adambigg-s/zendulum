#[repr(C)]
#[derive(bytemuck::Pod, bytemuck::Zeroable, Debug, Default, Clone, Copy)]
pub struct State
{
     pub theta1: f64,
     pub theta2: f64,
     pub dtheta1: f64,
     pub dtheta2: f64,
}

impl State
{
     pub fn parse_bytes(buffer: &[u8]) -> anyhow::Result<Self>
     {
          if buffer.len() < size_of::<Self>()
          {
               anyhow::bail!(
                    "Recv buffer too small: {} bytes\nExpected {} bytes",
                    size_of_val(buffer),
                    size_of::<Self>() );
          }

          bytemuck::try_pod_read_unaligned::<Self>(&buffer[0 .. size_of::<Self>()])
               .map_err(|err| anyhow::anyhow!("Failed to parse bytes: {:?}", err))
     }
}
