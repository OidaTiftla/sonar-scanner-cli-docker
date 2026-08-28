{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  buildInputs = [
    nixpkgs-fmt
    curl
    jq
    perl
  ];

  shellHook = ''
    # ...
  '';
}
