{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    zig-overlay,
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        overlays = [
          (final: prev: {
            zigpkgs = zig-overlay.packages.${prev.system}."0.13.0";
          })
        ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
        with pkgs; {
          devShells.default = mkShell {
            buildInputs = [zig];
            shellHook = ''
              # We unset some NIX environment variables that might interfere with the zig compiler.
              # Issue: https://github.com/ziglang/zig/issues/18998
              unset NIX_CFLAGS_COMPILE
              unset NIX_LDFLAGS
              printf '\n'
              echo "Running Zig Version: $(zig version)"
            '';
          };
        }
    );
}
