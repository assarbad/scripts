#!/usr/bin/env ruby

contents = IO.read(ARGV[0])
contents = contents.encode(
    "cp1252",
      :fallback => {
        "\u0081" => "\x81".force_encoding("cp1252"),
        "\u008D" => "\x8D".force_encoding("cp1252"),
        "\u008F" => "\x8F".force_encoding("cp1252"),
        "\u0090" => "\x90".force_encoding("cp1252"),
        "\u009D" => "\x9D".force_encoding("cp1252")
      })
    .force_encoding("UTF-8")
outfname = ARGV[0] + ".fixed"
File.write(outfname, contents, mode: 'w')
