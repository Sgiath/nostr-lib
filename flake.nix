{
  description = "Nostr lib in Elixir";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = {parts, ...} @ inputs:
    parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      perSystem = {pkgs, ...}: let
        beamPackages = pkgs.beam_minimal.packages.erlang_27;
        elixir = beamPackages.elixir_1_17;
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            elixir
            git
            autoreconfHook
          ];

          env = {
            ERL_AFLAGS = "+pc unicode -kernel shell_history enabled";
            ELIXIR_ERL_OPTIONS = "+sssdio 128";
          };
        };
      };
    };
}
