use std::net;
use std::thread;
use std::time;

const FPS: f32 = 100f32;
const POLL_RATE: f32 = time::Duration::from_secs(1).as_millis() as f32 / FPS;
const SHUTDOWN: &[u8] = "SHUTDOWN".as_bytes();

fn main() -> anyhow::Result<()>
{
     let socket = net::UdpSocket::bind("127.0.0.1:6767")?;

     let mut buf = [0u8; 2048];

     loop
     {
          let (len, src) = socket.recv_from(&mut buf)?;
          let recv = &buf[0 .. len];
          let sring = str::from_utf8(recv)?;
          println!("Recieved this stuff: {:?}\nAs string: {}\nFrom: {}", recv, sring, src);

          // if recv == SHUTDOWN
          // {
          //      break;
          // }
     }

     thread::sleep(time::Duration::from_secs(5));

     Ok(())
}
