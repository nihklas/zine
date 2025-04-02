{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    zls.url = "github:zigtools/zls/0.14.0";
    zls.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
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
        });
  in {
    devShells = eachSystem ({
      system,
      pkgs,
      ...
    }: {
      default = pkgs.mkShellNoCC {
        packages = [
          zls.packages.${system}.default
          pkgs.zig_0_14
        ];
      };
    });

    packages = eachSystem ({
      pkgs,
      target,
      ...
    }: {
      default = pkgs.stdenvNoCC.mkDerivation {
        name = "zine";
        version = "0.0.0";
        meta.mainProgram = "zine";
        src = pkgs.lib.cleanSource ./.;
        nativeBuildInputs = [pkgs.zig_0_14];
        dontConfigure = true;
        dontInstall = true;
        dontCheck = true;
        buildPhase = ''
          NO_COLOR=1 # prevent escape codes from messing up the `nix log`
          PACKAGE_DIR=${pkgs.callPackage ./deps.nix {zig = pkgs.zig;}}
          zig build install --global-cache-dir $(pwd)/.cache --system $PACKAGE_DIR -Dtarget=${target} -Doptimize=ReleaseFast --prefix $out
        '';
      };
    });
  };
}

