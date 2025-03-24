{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    zig-overlay.url = "github:mitchellh/zig-overlay";
    zig-overlay.inputs.nixpkgs.follows = "nixpkgs";

    zls.url = "github:zigtools/zls/0.14.0";
    zls.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    zig-overlay,
    zls,
    ...
  }: let
    systems = ["aarch64-darwin" "x86_64-linux"];
    eachSystem = function:
      nixpkgs.lib.genAttrs systems (system:
        function {
          inherit system;
          target = builtins.replaceStrings ["darwin"] ["macos"] system;
          pkgs = nixpkgs.legacyPackages.${system};
          zig = zig-overlay.packages.${system}."0.14.0";
        });
  in {
    devShells = eachSystem ({
      system,
      pkgs,
      zig,
      ...
    }: {
      default = pkgs.mkShellNoCC {
        packages = [
          zls.packages.${system}.default
          zig
        ];
      };
    });

    packages = eachSystem ({
      pkgs,
      target,
      zig,
      ...
    }: {
      default = pkgs.stdenvNoCC.mkDerivation {
        # name = "name";
        # version = "0.0.1";
        # meta.mainProgram = "name";
        src = pkgs.lib.cleanSource ./.;
        nativeBuildInputs = [zig];
        dontConfigure = true;
        dontInstall = true;
        dontCheck = true;
        buildPhase = ''
          NO_COLOR=1 # prevent escape codes from messing up the `nix log`
          PACKAGE_DIR=${pkgs.callPackage ./deps.nix {zig = pkgs.zig;}}
          zig build install --global-cache-dir $(pwd)/.cache --system $PACKAGE_DIR -Dtarget=${target} -Doptimize=ReleaseSafe --prefix $out
        '';
      };
    });
  };
}

