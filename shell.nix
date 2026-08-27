{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  buildInputs = [
    nixpkgs-fmt
    curl
    jq
    perl
    pup # Parsing HTML at the command line: https://github.com/ericchiang/pup
  ];

  shellHook = ''
    # ...
  '';
}
