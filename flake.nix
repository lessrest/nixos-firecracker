{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.hamlet = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [(import ./system.nix)];
    };
  };
}
