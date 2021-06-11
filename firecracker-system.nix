{ pkgs, config, lib, ... }:

let
  kernel = pkgs.linux_5_12;

in {
  boot.isContainer = true;
  
  boot.kernelPackages = pkgs.linuxPackages_custom {
    inherit (kernel) src version;
    configfile = ./firecracker-kernel.config;
  };

  fileSystems."/" = { device = "/dev/vda"; };

  services.mingetty.autologinUser = "root";

  users.users.root.initialHashedPassword = "";

  networking.dhcpcd.enable = false;

  boot.loader.grub.enable = false;

  system.activationScripts.installInitScript = ''
    mkdir -p /sbin
    ln -fs $systemConfig/init /sbin/init
  '';

  boot.postBootCommands =
    ''
      # After booting, register the contents of the Nix store in the Nix
      # database.
      if [ -f /nix-path-registration ]; then
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration &&
        rm /nix-path-registration
      fi
      # nixos-rebuild also requires a "system" profile
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    '';

  environment.systemPackages = with pkgs; [
    clojure
  ];
}
