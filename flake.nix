{
  description = "weby website builder with just and typst (0.13)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
     # ensures typst = 0.13.1, once the issue with svg's are fixed we can move to the latest version
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        devShells.default = pkgs.mkShell {
          # Tools needed for development/build
          packages = with pkgs; [
            just        # task runner
            typst       # 0.13.0 (from nixos-24.05)
            miniserve   
          ];

          # Make `just` find the right tools in PATH
          shellHook = ''
            echo "✅ Ready! Typst $(typst --version | cut -d' ' -f2), Just $(just --version)"
            echo "👉 Run 'just' to see available commands"
          '';
        };

        # a "build" app for CI's, not fully sure about this
        apps.build = flake-utils.lib.mkApp {
          drv = pkgs.stdenv.mkDerivation {
            name = "build-website";
            src = ./.;
            dontUnpack = true;

            nativeBuildInputs = with pkgs; [ just typst ];

            buildPhase = ''
              runHook preBuild
              just build
              runHook postBuild
            '';

            installPhase = ''
              mkdir -p $out
              cp -r dist/* $out/
            '';

            meta.description = "Weby builder";
          };
        };
      });
}
