# Telnet Client in Zig

[![MIT License](https://img.shields.io/badge/license-MIT-blue)](https://choosealicense.com/licenses/mit/) [![Run Zig Tests](https://github.com/michidk/telnet-zig/actions/workflows/test.yaml/badge.svg)](https://github.com/michidk/telnet-zig/actions/workflows/test.yaml)

This project is a Zig implementation of a simple telnet client.

[Telnet](https://en.wikipedia.org/wiki/Telnet), one of the earliest internet protocols, is used to provide a bidirectional interactive text-based communication facility, primarily over a terminal interface, allowing users to connect to a remote host or server.

[Zig](https://ziglang.org/) is a general-purpose programming language designed for robustness, optimality, and clarity, primarily aimed at maintaining performance and improving upon concepts from C.

This implementation is not as feature-rich and customizable as the [inetutils implementation](https://github.com/guillemj/inetutils/tree/master/telnet) but aims to cover the same feature set as the [curl implementation](https://github.com/curl/curl/blob/master/lib/telnet.c).

This project initially helped me to learn and evaluate Zig. I documented my insights and reflections in a blog post found [here](https://blog.lohr.dev/after-a-day-of-programming-in-zig).


## Features

- Basic telnet protocol functionality

## Installation

- Install the [Zig](https://ziglang.org/download/) compiler
- Run `zig build` to build the project
- Run `zig build run` to run the telnet client (or use [just](https://github.com/casey/just))

## Run

Run with Zig:

```bash
zig build run -- telnet://horizons.jpl.nasa.gov:6775
```

Or run the executable directly (after building):

```bash
./telnet-zig horizons.jpl.nasa.gov:6775
```

## Usage

To display the help, run the telnet client with the `--help` flag:

```bash
./telnet-zig --help
  -h, --help
          Display this help.

  -u, --usage
          Displays a short command usage

  <str>
          The telnet URI to connect to.
```
