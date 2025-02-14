{
  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, fenix, nixpkgs }:
    let
      inherit (nixpkgs.lib)
        genAttrs
        importTOML
        optionals
        sourceByRegex
        ;

      eachSystem = f: genAttrs
        [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-darwin"
          "x86_64-linux"
        ]
        (system: f nixpkgs.legacyPackages.${system});

      packageFor = pkgs:
        let
          rust = fenix.packages.${pkgs.stdenv.hostPlatform.system}.minimal.toolchain;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rust;
            rustc = rust;
          };
        in
        rustPlatform.buildRustPackage {
          pname = "typst";
          inherit ((importTOML ./Cargo.toml).workspace.package) version;

          src = sourceByRegex ./. [
            "(assets|cli|docs|library|macros|src|tests)(/.*)?"
            ''Cargo\.(toml|lock)''
            ''build\.rs''
          ];

          cargoLock = {
            lockFile = ./Cargo.lock;
            allowBuiltinFetchGit = true;
          };

          nativeBuildInputs = [
            pkgs.installShellFiles
          ];

          buildInputs = optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.CoreServices
          ];

          postInstall = ''
            installManPage cli/artifacts/*.1
            installShellCompletion \
              cli/artifacts/typst.{bash,fish} \
              --zsh cli/artifacts/_typst
          '';

          GEN_ARTIFACTS = "artifacts";
        };
    in
    {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages =
            let
              fenix' = fenix.packages.${pkgs.stdenv.hostPlatform.system};
            in
            [
              (fenix'.default.withComponents [
                "cargo"
                "clippy"
                "rustc"
                "rustfmt"
              ])
              fenix'.rust-analyzer
            ];

          buildInputs = optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.CoreServices
            pkgs.libiconv
          ];
        };
      });

      formatter = eachSystem (pkgs: pkgs.nixpkgs-fmt);

      overlays.default = _: prev: {
        typst-dev = packageFor prev;
      };

      packages = eachSystem (pkgs: {
        default = packageFor pkgs;
      });
    };
}
