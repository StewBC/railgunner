"""Encode the IIgs game framebuffer with its fixed palette."""
import struct,zlib

def save_png(path,frame):
    palette=[0x000000,0xffffff,0x68372b,0x70a4b2,0x6f3d86,0x588d43,0x352879,0xb8c76f,0x6f4f25,0x433900,0x9a6759,0x444444,0x6c6c6c,0x9ad284,0x6c5eb5,0x959595]
    def chunk(kind,blob):return struct.pack('>I',len(blob))+kind+blob+struct.pack('>I',zlib.crc32(kind+blob)&0xffffffff)
    pixels=bytearray()
    for row in range(200):
        pixels.append(0)
        for b in frame[row*160:(row+1)*160]:pixels.extend((b>>4,b&15))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',320,200,8,3,0,0,0))+chunk(b'PLTE',b''.join(c.to_bytes(3,'big') for c in palette))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b''))
