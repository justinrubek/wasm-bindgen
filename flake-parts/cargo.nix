{
  inputs,
  self,
  ...
} @ part-inputs: {
  imports = [];

  perSystem = {
    config,
    pkgs,
    lib,
    system,
    inputs',
    self',
    ...
  }: let
    # packages required for building the rust packages
    extraPackages = [
      pkgs.pkg-config
      pkgs.openssl
      pkgs.nodejs
    ];
    withExtraPackages = base: base ++ extraPackages;

    craneLib = (inputs.crane.mkLib pkgs).overrideToolchain self'.packages.rust-toolchain;

    commonArgs = rec {
      src = inputs.nix-filter.lib {
        root = ../.;
        include = [
          "benchmarks"
          "crates"
          "Cargo.toml"
          "Cargo.lock"
          "examples"
          "src"
          "tests"
        ];
      };

      pname = "wasm-bindgen";

      nativeBuildInputs = withExtraPackages [];
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeBuildInputs;
      SQLX_OFFLINE = true;
    };

    cargoArtifacts = craneLib.buildDepsOnly (commonArgs
      // {
      });
    packages = {
      default = packages.cli;
      wasm-bindgen-cli = craneLib.buildPackage ({
          pname = "wasm-bindgen-cli";
          inherit cargoArtifacts;
          cargoExtraArgs = "-p wasm-bindgen-cli";
          meta.mainProgram = "wasm-bindgen-cli";
          doCheck = false;
        }
        // commonArgs);

      cargo-doc = craneLib.cargoDoc ({
          inherit cargoArtifacts;
        }
        // commonArgs);
    };

    checks = {
      clippy = craneLib.cargoClippy (commonArgs
        // {
          inherit cargoArtifacts;
          cargoClippyExtraArgs = "--all-features -- --deny warnings";
        });

      rust-fmt = craneLib.cargoFmt (commonArgs
        // {
          inherit (commonArgs) src;
        });

      rust-tests = craneLib.cargoNextest (commonArgs
        // {
          inherit cargoArtifacts;
          partitions = 1;
          partitionType = "count";
        });
    };
  in rec {
    inherit packages checks;

    apps = {
      wasm-bindgen-cli = {
        type = "app";
        program = pkgs.lib.getBin self'.packages.wasm-bindgen-cli;
      };
      default = apps.wasm-bindgen-cli;
    };

    legacyPackages = {
      cargoExtraPackages = extraPackages;
    };
  };
}
