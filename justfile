fmt:
  zig fmt .

run:
  zig build run

build:
  zig build

nasa:
  zig build run -- telnet://horizons.jpl.nasa.gov:6775

clean:
  rm -rf zig-cache
  rm -rf zig-out
