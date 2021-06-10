{ pkgs, ... }:

let
  mbrock-ssh = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzUOiIf7ohFtwfnvemmxKItX1zzpvVNZ6miAg4n5p91Az9EQFyRrH7Cylm0Vc9QX62entlFcMx3VS6j+/KWUrM7wPmtiN/+wXT7pVC5i/JP3vvUWMyq2ftq47j2Vl289qDdVgNsO6YaBNEquMvfBvSPwIOSulpLqtow9K2MQ9pliRJl8CL7C1KmT9tWpkWrdyscrbWSFNvYrXXiG6S+YOkSLoluDPn+iyXXPnzCJ2Nhtw2445dHLmbEoCwIImHVf+WrWk/GZDcSjmQMKLVixdO2wfINYd02KmKmYZ+1nc4YnLpr0/wf+5TDkkIIrcUYLkFhjdtKqEz/Oce2Ho9IDJT mikael.brockman@gmail.com";

in {
  import = [./hetzner-hardware.nix];

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  networking.hostName = "hamlet";
  time.timeZone = "Europe/Riga";

  users.users.root.openssh.authorizedKeys.keys = [mbrock-ssh];
  users.users.mbrock = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [mbrock-ssh];
  };

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/nvme0n1";

  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;

  system.stateVersion = "21.11";
}
