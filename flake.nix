{
  description = "gpu-proxy - C++ Stratum mining proxy for CR29/Kryptex with TLS, pool failover, and worker management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Support both x86_64-linux and aarch64-linux
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          gpu-proxy = pkgs.stdenv.mkDerivation rec {
            pname = "gpu-proxy";
            version = "2.0.0";

            src = self;

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
            ];
            buildInputs = with pkgs; [
              openssl
              nlohmann_json
            ];

            cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];

            preConfigure = ''
              export NIX_CFLAGS_COMPILE="-I${pkgs.nlohmann_json}/include/nlohmann $NIX_CFLAGS_COMPILE"
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp gpu-proxy $out/bin/
            '';
          };

          # OCI container image
          container = pkgs.dockerTools.buildLayeredImage {
            name = "gpu-proxy";
            tag = "latest";
            contents = [
              gpu-proxy
              pkgs.bash
              pkgs.coreutils
              pkgs.cacert
            ];
            config = {
              Cmd = [
                "${gpu-proxy}/bin/gpu-proxy"
              ];
              ExposedPorts = {
                "3334/tcp" = { };
                "8083/tcp" = { };
              };
              Env = [
                "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
              ];
            };
          };
        in
        {
          inherit gpu-proxy container;
          default = gpu-proxy;
        }
      );

      kubernetesModules.default = import ./kubernetes/module.nix;

      nixosModules.default = import ./nix/module.nix self;

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cmake
              pkg-config
              openssl
              nlohmann_json
              gcc
              gdb
            ];

            shellHook = ''
              echo "gpu-proxy dev shell"
              echo "  cmake -B build && cmake --build build"
            '';
          };
        }
      );

      checks = forAllSystems (
        system:
        {
          build = self.packages.${system}.gpu-proxy;
        }
      );
    };
}
